import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import '../progress/domain/body_weight.dart';
import 'domain/nutrition_targets_rules.dart';

/// Editor for the daily energy and macro targets.
///
/// Automatic mode shows the formula result; typing a value and saving switches
/// to manual mode. Manual mode keeps the values until the user returns to the
/// automatic calculation.
class NutritionTargetsPage extends StatefulWidget {
  const NutritionTargetsPage({super.key});

  @override
  State<NutritionTargetsPage> createState() => _NutritionTargetsPageState();
}

class _NutritionTargetsPageState extends State<NutritionTargetsPage> {
  AppServices? _services;
  Future<TargetsState>? _future;
  TargetsState? _filledFrom;
  bool _saving = false;

  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (!identical(services, _services)) {
      _services = services;
      _reload();
    }
  }

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  /// Re-reads the stored targets and refills the fields from them.
  void _reload() {
    setState(() {
      _future = TargetsState.load(_services!.database);
    });
  }

  /// Fills the fields once per loaded state. A reload keeps the old snapshot
  /// until the new one arrives, so comparing identities avoids stale values.
  void _fillFrom(TargetsState state) {
    if (identical(_filledFrom, state)) return;
    _filledFrom = state;
    final profile = state.profile;
    _kcal.text = profile.calorieGoal.round().toString();
    _protein.text = profile.proteinGoal.round().toString();
    _carbs.text = profile.carbsGoal.round().toString();
    _fat.text = profile.fatGoal.round().toString();
  }

  double? get _kcalValue => TargetsRules.parse(_kcal.text);
  double? get _proteinValue => TargetsRules.parse(_protein.text);
  double? get _carbsValue => TargetsRules.parse(_carbs.text);
  double? get _fatValue => TargetsRules.parse(_fat.text);

  bool get _valid =>
      TargetsRules.checkKcal(_kcalValue) == null &&
      TargetsRules.checkGrams(_proteinValue) == null &&
      TargetsRules.checkGrams(_carbsValue) == null &&
      TargetsRules.checkGrams(_fatValue) == null;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    // The footer depends on the field values, so the whole scaffold is built
    // after the stored state has been loaded into the fields.
    return FutureBuilder<TargetsState>(
      future: _future,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return VyroSubpageScaffold(
            title: t.get('targetsTitle'),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        _fillFrom(state);
        return VyroSubpageScaffold(
          title: t.get('targetsTitle'),
          body: VyroPageBody(children: _children(t, state)),
          footer: VyroPrimaryButton(
            label: t.get('targetsSave'),
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _valid && !_saving ? _save : null,
          ),
        );
      },
    );
  }

  List<Widget> _children(VyroStrings t, TargetsState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal = _kcalValue;
    final protein = _proteinValue;
    final carbs = _carbsValue;
    final fat = _fatValue;
    final mismatch =
        kcal != null &&
        protein != null &&
        carbs != null &&
        fat != null &&
        TargetsRules.checkKcal(kcal) == null &&
        TargetsRules.macrosMismatch(
          kcal: kcal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
    final implied = (protein ?? 0) * 4 + (carbs ?? 0) * 4 + (fat ?? 0) * 9;
    final diff = kcal == null || kcal <= 0
        ? 0
        : ((implied - kcal).abs() / kcal * 100).round();
    final latest = state.latestWeight;

    return [
      VyroCard(
        tint: scheme.primary.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.manual
                      ? Icons.tune_rounded
                      : Icons.auto_awesome_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.get(
                      state.manual ? 'targetsModeManual' : 'targetsModeAuto',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t.get(state.manual ? 'targetsManualBody' : 'targetsAutoBody'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              latest == null
                  ? t
                        .get('targetsBasisProfile')
                        .replaceAll(
                          '{weight}',
                          formatBodyWeight(
                            state.profile.weightKg,
                            english: t.isEnglish,
                          ),
                        )
                  : t
                        .get('targetsBasisLatest')
                        .replaceAll(
                          '{weight}',
                          formatBodyWeight(
                            latest.weightKg,
                            english: t.isEnglish,
                          ),
                        )
                        .replaceAll(
                          '{date}',
                          formatBodyDate(bodyDay(latest.measuredAt)),
                        ),
              style: theme.textTheme.labelMedium,
            ),
            if (state.manual) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving ? null : _useAutomatic,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(t.get('targetsBackToAuto')),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ],
          ],
        ),
      ),
      if (state.weightChangedSinceManual) ...[
        const SizedBox(height: 12),
        VyroCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.get('targetsWeightHint'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _useAutomatic,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(t.get('targetsRecalc')),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _keepManual,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(t.get('targetsKeepManual')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      _Field(
        controller: _kcal,
        label: t.get('targetsKcal'),
        suffix: 'kcal',
        helper: t.get('targetsKcalHelp'),
        issue: TargetsRules.checkKcal(_kcalValue),
        messages: {
          TargetsIssue.invalid: t.get('targetsErrorInvalid'),
          TargetsIssue.kcalRange: t.get('targetsErrorKcal'),
        },
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 20),
      Text(t.get('targetsMacros'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      _Field(
        controller: _protein,
        label: t.get('protein'),
        suffix: 'g',
        issue: TargetsRules.checkGrams(_proteinValue),
        messages: {
          TargetsIssue.invalid: t.get('targetsErrorInvalid'),
          TargetsIssue.gramsRange: t.get('targetsErrorGrams'),
        },
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 10),
      _Field(
        controller: _carbs,
        label: t.get('carbs'),
        suffix: 'g',
        issue: TargetsRules.checkGrams(_carbsValue),
        messages: {
          TargetsIssue.invalid: t.get('targetsErrorInvalid'),
          TargetsIssue.gramsRange: t.get('targetsErrorGrams'),
        },
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 10),
      _Field(
        controller: _fat,
        label: t.get('fat'),
        suffix: 'g',
        issue: TargetsRules.checkGrams(_fatValue),
        messages: {
          TargetsIssue.invalid: t.get('targetsErrorInvalid'),
          TargetsIssue.gramsRange: t.get('targetsErrorGrams'),
        },
        onChanged: () => setState(() {}),
      ),
      if (mismatch) ...[
        const SizedBox(height: 14),
        VyroCard(
          padding: const EdgeInsets.all(16),
          tint: scheme.error.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t
                    .get('targetsMacroKcal')
                    .replaceAll('{kcal}', implied.round().toString()),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                t.get('targetsMismatch').replaceAll('{diff}', diff.toString()),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() {
                  _kcal.text = implied.round().toString();
                }),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(t.get('targetsAdjustKcal')),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      Text(t.get('targetsDisclaimer'), style: theme.textTheme.bodySmall),
    ];
  }

  Future<void> _save() async {
    final t = stringsOf(context);
    final services = _services!;
    final settings = SettingsScope.maybeOf(context);
    setState(() => _saving = true);
    await services.database.saveManualTargets(
      kcal: _kcalValue!,
      protein: _proteinValue!,
      carbs: _carbsValue!,
      fat: _fatValue!,
    );
    await settings?.refreshProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    _reload();
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(t.get('targetsSaved'))));
  }

  Future<void> _useAutomatic() async {
    final t = stringsOf(context);
    final services = _services!;
    final settings = SettingsScope.maybeOf(context);
    setState(() => _saving = true);
    await services.database.useAutomaticTargets();
    await settings?.refreshProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    _reload();
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(t.get('targetsRestored'))));
  }

  Future<void> _keepManual() async {
    final services = _services!;
    await services.database.keepManualTargets();
    if (!mounted) return;
    _reload();
  }
}

/// Opens the targets editor. Shown under the diary and home summaries.
class NutritionTargetsLink extends StatelessWidget {
  const NutritionTargetsLink({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/nutrition-targets'),
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(t.get('targetsEdit')),
        style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
      ),
    );
  }
}

/// Shows the non-blocking message after a weight change. Automatic targets
/// that changed are reported with their old and new values. In manual mode a
/// moved weight offers one tap to recalculate; ignoring it keeps the targets.
void showWeightTargetsFeedback(
  BuildContext context, {
  required VyroStrings t,
  required TargetsState before,
  required TargetsState after,
  required Future<void> Function() onRecalculate,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  switch (weightTargetsOutcome(before: before, after: after)) {
    case WeightTargetsOutcome.none:
      return;
    case WeightTargetsOutcome.updated:
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              t
                  .get('targetsUpdated')
                  .replaceAll(
                    '{from}',
                    before.profile.calorieGoal.round().toString(),
                  )
                  .replaceAll(
                    '{to}',
                    after.profile.calorieGoal.round().toString(),
                  )
                  .replaceAll(
                    '{weight}',
                    formatBodyWeight(after.weightKg, english: t.isEnglish),
                  ),
            ),
          ),
        );
    case WeightTargetsOutcome.hint:
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(t.get('targetsWeightHint')),
            action: SnackBarAction(
              label: t.get('targetsRecalc'),
              onPressed: () => onRecalculate(),
            ),
          ),
        );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.issue,
    required this.messages,
    required this.onChanged,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? helper;
  final TargetsIssue? issue;
  final Map<TargetsIssue, String> messages;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final issueKey = issue;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: issue == null ? helper : null,
        errorText: issueKey == null ? null : messages[issueKey],
      ),
    );
  }
}
