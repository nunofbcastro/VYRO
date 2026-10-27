import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ai/on_device_llm.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/vyro_ui.dart';
import '../nutrition/domain/food_product.dart';
import '../workouts/data/workout_repository.dart';
import '../workouts/domain/plan_generator.dart';
import '../workouts/domain/week_schedule.dart';
import 'domain/local_assistant.dart';
import 'domain/meal_math.dart';
import 'domain/meal_proposal.dart';
import 'domain/model_answer.dart';
import '../nutrition/data/food_database.dart';
import '../nutrition/meals.dart';
import '../motion_engine/workout_analysis_history/motion_history_repository.dart';
import 'meal_log_sheet.dart';
import 'widgets/answer_footnote.dart';
import 'widgets/chat_message_bubble.dart';

/// Q&A with the operating system's on-device model (Apple Intelligence on
/// iOS 26+, Gemini Nano on supported Android phones).
///
/// The conversation lives only in memory. Answers are grounded in the
/// user's local data and framed as general guidance, never medical advice.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <ChatTurn>[];

  LlmStatus? _status;
  bool _busy = false;
  bool _preparing = false;
  int _requestId = 0;

  /// Meal cards, by turn index. Computed from the database, never from prose.
  final _resolved = <int, ResolvedMeal>{};
  final _rated = <int>{};
  final _sources = <int, String>{};
  final _footnotes = <int, String>{};

  OnDeviceLlm get _llm => AppServicesScope.of(context).llm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status == null) _checkStatus();
  }

  @override
  void dispose() {
    _requestId++;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await _llm.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _prepare() async {
    setState(() => _preparing = true);
    final status = await _llm.download();
    if (mounted) {
      setState(() {
        _status = status;
        _preparing = false;
      });
    }
  }

  /// Collects today's diary, goals and the weekly schedule from local data.
  Future<AssistantContext> _context(VyroStrings t) async {
    final services = AppServicesScope.of(context);
    final profile = await services.database.getUserProfile();
    final entries = await services.database
        .watchEntriesForDay(dayKey(DateTime.now()))
        .first;
    double sum(double? Function(FoodEntryRecord) pick) => entries.fold(
      0,
      (total, e) => total + (nutrientForPortion(pick(e), e.quantityGrams) ?? 0),
    );
    final repository = services.workoutRepository;
    final plan = await repository.reloadPlan();
    final week = buildWeek(
      today: DateTime.now(),
      slots: plan == null ? const [] : WorkoutRepository.slotsOf(plan),
      done: await repository.watchDoneDays().first,
      skipped: await repository.watchSkippedDays().first,
    );
    final next = nextWorkout(week);
    final progress = weekProgress(week);
    WorkoutDayData? nextDay;
    for (final day in plan?.days ?? const <WorkoutDayData>[]) {
      if (day.day.id == next?.slot?.dayId) nextDay = day;
    }
    final yesterday = await services.database
        .watchEntriesForDay(
          dayKey(DateTime.now().subtract(const Duration(days: 1))),
        )
        .first;
    final analyses = await MotionHistoryRepository(
      services.database,
    ).watch(limit: 1).first;
    String? lastSet;
    if (analyses.isNotEmpty) {
      final row = analyses.first;
      final names = await services.database
          .select(services.database.exerciseCatalog)
          .get();
      final matching = names.where((e) => e.exerciseKey == row.exerciseKey);
      final name = matching.isEmpty
          ? row.exerciseKey.replaceAll('_', ' ')
          : (t.isEnglish ? matching.first.nameEn : matching.first.namePt);
      lastSet = MotionHistoryRepository.describe(
        row,
        name: name,
        english: t.isEnglish,
      );
    }
    return AssistantContext(
      goal: switch (profile?.goal) {
        'strength' => t.get('goalStrength'),
        'nutrition' => t.get('goalNutrition'),
        _ => t.get('goalRoutine'),
      },
      kcalGoal: profile?.calorieGoal.round(),
      proteinGoal: profile?.proteinGoal.round(),
      kcalToday: sum((e) => e.kcalPer100g).round(),
      proteinToday: sum((e) => e.proteinPer100g).round(),
      carbsGoal: profile?.carbsGoal.round(),
      fatGoal: profile?.fatGoal.round(),
      carbsToday: sum((e) => e.carbsPer100g).round(),
      fatToday: sum((e) => e.fatPer100g).round(),
      dietaryChoice: profile?.dietaryChoice,
      partialNutrition: entries.any(
        (e) =>
            e.kcalPer100g == null ||
            e.proteinPer100g == null ||
            e.carbsPer100g == null ||
            e.fatPer100g == null,
      ),
      confirmedPreferences: (await services.localIntelligence.memories()).values
          .toList(),
      previousDinner: [
        for (final e in yesterday.where((e) => e.mealType == 'dinner'))
          '${e.name} — ${e.quantityGrams.round()} g',
      ],
      lastSet: lastSet,
      foodsToday: [
        for (final e in entries) '${e.name} (${e.quantityGrams.round()} g)',
      ],
      planTitle: plan?.plan.title,
      nextWorkout: next?.slot == null
          ? null
          : (t.isEnglish ? next!.slot!.nameEn : next!.slot!.namePt),
      nextWorkoutDay: next == null
          ? null
          : weekdayLong(next.date.weekday, english: t.isEnglish),
      nextExercises: [
        for (final e in nextDay?.exercises ?? const <PlannedExercise>[])
          '${t.isEnglish ? e.info.nameEn : e.info.namePt} '
              '${e.planExercise.sets}×${e.planExercise.repTarget}',
      ],
      weekDone: progress.done,
      weekTotal: progress.scheduled,
    );
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _input.text).trim();
    if (question.isEmpty || _busy) return;
    final request = ++_requestId;
    final t = stringsOf(context);
    final services = AppServicesScope.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final history = List<ChatTurn>.of(_turns);
    setState(() {
      _turns.add(ChatTurn(fromUser: true, text: question));
      _busy = true;
      _input.clear();
    });
    _scrollToEnd();
    try {
      final facts = await _context(t);
      final db = await FoodDatabase.load();
      if (!mounted || request != _requestId) return;
      var answer = answerLocally(
        question,
        facts,
        db,
        english: t.isEnglish,
        meal: mealForTime(DateTime.now()),
      );
      var source = t.isEnglish
          ? 'Calculated from local data'
          : 'Calculado a partir de dados locais';
      ResolvedMeal? card;
      String? footnote;
      if (answer == null && _status == LlmStatus.available) {
        final prompt = buildAssistantPrompt(
          question: question,
          context: facts,
          history: history,
          english: t.isEnglish,
        );
        try {
          final composed = await answerFromModel(
            llm: services.llm,
            prompt: prompt,
            db: db,
            diet: facts.dietaryChoice,
            english: t.isEnglish,
          );
          card = composed.meal;
          footnote = composed.footnote;
          answer = LocalAssistantAnswer(
            composed.text.isEmpty
                ? localAssistantHelp(t.isEnglish)
                : composed.text,
          );
          source = t.isEnglish
              ? 'Generated on device; numbers checked against the local database'
              : 'Gerado no dispositivo; números verificados na base local';
        } catch (_) {
          answer = LocalAssistantAnswer(localAssistantHelp(t.isEnglish));
        }
      }
      answer ??= LocalAssistantAnswer(localAssistantHelp(t.isEnglish));
      if (!mounted || request != _requestId) return;
      final response = answer;
      if (card == null && response.proposal != null) {
        card = resolveMeal(response.proposal!, db, diet: facts.dietaryChoice);
      }
      setState(() {
        final index = _turns.length;
        if (card != null) _resolved[index] = card;
        _sources[index] = source;
        if (footnote != null) _footnotes[index] = footnote;
        _turns.add(ChatTurn(fromUser: false, text: response.text));
      });
    } catch (_) {
      if (mounted && request == _requestId)
        setState(
          () => _turns.add(
            ChatTurn(fromUser: false, text: t.get('assistantError')),
          ),
        );
    } finally {
      if (mounted && request == _requestId) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _rate(int index, bool helpful) async {
    if (_rated.contains(index)) return;
    setState(() => _rated.add(index));
    try {
      await AppServicesScope.of(
        context,
      ).localIntelligence.recordAssistantFeedback(helpful);
    } catch (_) {
      if (mounted) {
        setState(() => _rated.remove(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(stringsOf(context).get('localError'))),
        );
      }
    }
  }

  Future<void> _logMeal(MealProposal proposal) async {
    final t = stringsOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final added = await showMealLogSheet(context, proposal);
    if (added != null && added > 0) {
      messenger?.showSnackBar(
        SnackBar(content: Text('$added ${t.get('logMealAdded')}')),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: VyroMotion.normal,
          curve: VyroMotion.curve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final status = _status;
    final ready = status == LlmStatus.available;
    return VyroSubpageScaffold(
      title: t.get('assistant'),
      actions: [
        VyroRoundButton(
          icon: Icons.psychology_outlined,
          tooltip: t.isEnglish ? 'Your local data' : 'Os teus dados locais',
          onPressed: () => Navigator.pushNamed(context, '/local-intelligence'),
        ),
        if (_turns.isNotEmpty)
          VyroRoundButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: t.get('assistantClear'),
            onPressed: () => setState(() {
              _requestId++;
              _busy = false;
              _rated.clear();
              _sources.clear();
              _footnotes.clear();
              _resolved.clear();
              _turns.clear();
            }),
          ),
      ],
      footer: _composer(t),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                _Header(status: status),
                const SizedBox(height: 16),
                if (!ready)
                  _StatusCard(
                    status: status,
                    preparing: _preparing,
                    onPrepare: _prepare,
                    onRetry: _checkStatus,
                  ),
                if (_turns.isEmpty) ...[
                  _SuggestionChip(
                    text: t.isEnglish
                        ? 'What is left today?'
                        : 'Quanto me falta hoje?',
                    onTap: () => _send(
                      t.isEnglish
                          ? 'What is left today?'
                          : 'Quanto me falta hoje?',
                    ),
                  ),
                  _SuggestionChip(
                    text: t.isEnglish
                        ? 'What is my next workout?'
                        : 'Qual é o próximo treino?',
                    onTap: () => _send(
                      t.isEnglish
                          ? 'What is my next workout?'
                          : 'Qual é o próximo treino?',
                    ),
                  ),
                  for (final key in const [
                    'assistantSuggestion1',
                    'assistantSuggestion2',
                    'assistantSuggestion3',
                  ]) ...[
                    VyroFadeSlideIn(
                      child: _SuggestionChip(
                        text: t.get(key),
                        onTap: () => _send(t.get(key)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                for (var i = 0; i < _turns.length; i++)
                  VyroFadeSlideIn(
                    offset: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChatMessageBubble(turn: _turns[i]),
                        if (_sources[i] != null)
                          Text(
                            _sources[i]!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        if (_footnotes[i] != null)
                          AnswerFootnote(text: _footnotes[i]!),
                        if (!_turns[i].fromUser)
                          Row(
                            children: [
                              IconButton(
                                tooltip: t.isEnglish ? 'Helpful' : 'Útil',
                                onPressed: _rated.contains(i)
                                    ? null
                                    : () => _rate(i, true),
                                icon: const Icon(
                                  Icons.thumb_up_outlined,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                tooltip: t.isEnglish
                                    ? 'Needs improvement'
                                    : 'A melhorar',
                                onPressed: _rated.contains(i)
                                    ? null
                                    : () => _rate(i, false),
                                icon: const Icon(
                                  Icons.thumb_down_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        if (_resolved[i] != null)
                          _ProposalCard(
                            meal: _resolved[i]!,
                            onAdd: () => _logMeal(_resolved[i]!.proposal),
                          ),
                      ],
                    ),
                  ),
                if (_busy) const _ThinkingBubble(),
                const SizedBox(height: 12),
                Text(
                  t.get('assistantDisclaimer'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Widget _composer(VyroStrings t) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _input,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(hintText: t.get('assistantPlaceholder')),
        ),
      ),
      const SizedBox(width: 10),
      IconButton.filled(
        tooltip: t.get('add'),
        onPressed: _busy
            ? () => setState(() {
                _requestId++;
                _busy = false;
              })
            : _send,
        icon: Icon(_busy ? Icons.stop_rounded : Icons.arrow_upward_rounded),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.status});
  final LlmStatus status;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: VyroTheme.accentTextOf(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.get('assistant'), style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      t.get('assistantExperimental'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(t.get('assistantPrivacy'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.preparing,
    required this.onPrepare,
    required this.onRetry,
  });

  final LlmStatus status;
  final bool preparing;
  final VoidCallback onPrepare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final (title, body) = switch (status) {
      LlmStatus.downloadable => (
        t.get('assistantTagline'),
        t.get('assistantDownloadable'),
      ),
      LlmStatus.downloading => (
        t.get('assistantTagline'),
        t.get('assistantDownloading'),
      ),
      _ => (
        t.get('assistantUnavailableTitle'),
        t.get('assistantUnavailableBody'),
      ),
    };
    return VyroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            status == LlmStatus.unavailable
                ? Icons.phonelink_off_rounded
                : Icons.downloading_rounded,
            size: 32,
            color: VyroTheme.accentTextOf(context),
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (status == LlmStatus.downloadable)
            VyroPrimaryButton(
              label: t.get('assistantDownload'),
              icon: Icons.download_rounded,
              loading: preparing,
              onPressed: onPrepare,
            )
          else
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.get('assistantRetryStatus')),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => VyroPressable(
    child: VyroCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: VyroTheme.accentTextOf(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Icon(Icons.north_east_rounded, size: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            stringsOf(context).get('assistantThinking'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

/// Foods the assistant proposed, with a button to review and log them.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.meal, required this.onAdd});
  final ResolvedMeal meal;
  final VoidCallback onAdd;

  Widget _item(BuildContext context, MealItemMatch match, bool en) {
    final theme = Theme.of(context);
    final food = match.food;
    final grams = match.item.grams;
    final detail = food == null
        ? null
        : '${(food.kcal * grams / 100).round()} kcal · '
              'P ${(food.protein * grams / 100).round()} g · '
              'H ${(food.carbs * grams / 100).round()} g · '
              'G ${(food.fat * grams / 100).round()} g';
    final alternatives = [for (final f in match.alternatives) f.name(en)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${grams.round()} g',
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food?.name(en) ?? match.item.name,
                  style: theme.textTheme.bodyMedium,
                ),
                if (detail != null)
                  Text(detail, style: theme.textTheme.bodySmall)
                else
                  Text(
                    en ? 'no database values' : 'sem valores na base',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (alternatives.isNotEmpty)
                  Text(
                    en
                        ? 'Could also be: ${alternatives.join(', ')}. Choose when reviewing.'
                        : 'Também pode ser: ${alternatives.join(', ')}. Escolhe ao rever.',
                    style: theme.textTheme.bodySmall,
                  )
                else if (match.needsConfirmation && food != null)
                  Text(
                    en
                        ? 'Confirm this food and its restrictions before logging.'
                        : 'Confirma este alimento e as restrições antes de registar.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final en = t.isEnglish;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: 12),
      child: VyroCard(
        radius: 18,
        tint: scheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  size: 18,
                  color: VyroTheme.accentTextOf(context),
                ),
                const SizedBox(width: 8),
                Text(
                  t.get('logMealProposal'),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final match in meal.items) _item(context, match, en),
            const SizedBox(height: 8),
            Text(
              meal.label(en),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.get('addToDiary')),
            ),
          ],
        ),
      ),
    );
  }
}
