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
import 'domain/meal_proposal.dart';
import 'meal_log_sheet.dart';

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

  /// Meal proposals parsed from assistant answers, by turn index.
  final _proposals = <int, MealProposal>{};
  LlmStatus? _status;
  bool _busy = false;
  bool _preparing = false;

  OnDeviceLlm get _llm => AppServicesScope.of(context).llm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status == null) _checkStatus();
  }

  @override
  void dispose() {
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
      slots: WorkoutRepository.slotsOf(plan),
      done: await repository.watchDoneDays().first,
      skipped: await repository.watchSkippedDays().first,
    );
    final next = nextWorkout(week);
    final progress = weekProgress(week);
    WorkoutDayData? nextDay;
    for (final day in plan.days) {
      if (day.day.id == next?.slot?.dayId) nextDay = day;
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
      foodsToday: [for (final e in entries) e.name],
      planTitle: plan.plan.title,
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
    final t = stringsOf(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _turns.add(ChatTurn(fromUser: true, text: question));
      _busy = true;
      _input.clear();
    });
    _scrollToEnd();
    try {
      final prompt = buildAssistantPrompt(
        question: question,
        context: await _context(t),
        history: _turns.sublist(0, _turns.length - 1),
        english: t.isEnglish,
      );
      final answer = await _llm.generate(prompt);
      final parsed = extractMealProposal(answer);
      if (mounted) {
        setState(() {
          if (parsed.proposal != null) {
            _proposals[_turns.length] = parsed.proposal!;
          }
          _turns.add(ChatTurn(fromUser: false, text: parsed.text));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _turns.add(
            ChatTurn(fromUser: false, text: t.get('assistantError')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
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
        if (_turns.isNotEmpty)
          VyroRoundButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: t.get('assistantClear'),
            onPressed: () => setState(() {
              _turns.clear();
              _proposals.clear();
            }),
          ),
      ],
      footer: ready ? _composer(t) : null,
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
                  )
                else if (_turns.isEmpty) ...[
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
                        _Bubble(turn: _turns[i]),
                        if (_proposals[i] != null)
                          _ProposalCard(
                            proposal: _proposals[i]!,
                            onAdd: () => _logMeal(_proposals[i]!),
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
        onPressed: _busy ? null : _send,
        icon: const Icon(Icons.arrow_upward_rounded),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final user = turn.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: EdgeInsets.only(
          bottom: 10,
          left: user ? 48 : 0,
          right: user ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user
              ? scheme.primary
              : (dark ? const Color(0xFF181B21) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 6),
            bottomRight: Radius.circular(user ? 6 : 18),
          ),
          border: user ? null : Border.all(color: scheme.outline, width: 0.8),
        ),
        child: SelectableText(
          turn.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: user ? scheme.onPrimary : scheme.onSurface,
            height: 1.45,
          ),
        ),
      ),
    );
  }
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
  const _ProposalCard({required this.proposal, required this.onAdd});
  final MealProposal proposal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
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
            for (final item in proposal.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${item.grams.round()} g',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(item.name, style: theme.textTheme.bodyMedium),
                    ),
                  ],
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
