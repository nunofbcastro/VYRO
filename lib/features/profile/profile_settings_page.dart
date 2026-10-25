import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/appearance_sheet.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/vyro_ui.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  AppServices? _services;
  Future<VyroProfile?>? _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (!identical(services, _services)) {
      _services = services;
      _profileFuture = services.database.getUserProfile();
    }
  }

  void _reload() {
    final services = _services;
    if (services == null) return;
    setState(() => _profileFuture = services.database.getUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final services = _services!;
    final settings = SettingsScope.of(context);
    return FutureBuilder<VyroProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return ContentPage(
          title: t.get('profile'),
          children: [
            VyroGroupedSection(
              children: [
                VyroListRow(
                  icon: Icons.person_rounded,
                  title: (profile?.name.trim().isNotEmpty ?? false)
                      ? profile!.name
                      : t.get('profileNotSet'),
                  subtitle:
                      '${t.get('goal')}: ${_goalName(t, profile?.goal ?? 'routine')}'
                      ' · ${(profile?.calorieGoal ?? 2200).round()} kcal',
                  onTap: () => _editProfile(context, services, profile),
                ),
                VyroListRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: t.get('assistant'),
                  subtitle: t.get('assistantTagline'),
                  onTap: () => Navigator.pushNamed(context, '/assistant'),
                ),
                VyroListRow(
                  icon: Icons.auto_awesome_outlined,
                  title: t.get('generatePlan'),
                  subtitle: t.get('generatePlanSubtitle'),
                  onTap: () => _generatePlan(context, services),
                ),
              ],
            ),
            const SizedBox(height: 24),
            VyroGroupedSection(
              header: t.get('settings'),
              children: [
                VyroListRow(
                  icon: Icons.palette_outlined,
                  iconColor: Theme.of(context).colorScheme.secondary,
                  title: t.get('appearance'),
                  value: t.get(switch (settings.themeMode) {
                    ThemeMode.dark => 'dark',
                    ThemeMode.light => 'light',
                    ThemeMode.system => 'system',
                  }),
                  onTap: () => showAppearanceSheet(context),
                ),
                VyroListRow(
                  icon: Icons.language_rounded,
                  iconColor: Theme.of(context).colorScheme.secondary,
                  title: t.get('language'),
                  value: settings.locale.languageCode == 'en' ? 'EN' : 'PT',
                  onTap: () => showAppearanceSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            VyroGroupedSection(
              header: t.get('privacy'),
              footer: t.get('privacyLocalExplanation'),
              children: [
                VyroListRow(
                  icon: Icons.policy_outlined,
                  title: t.get('privacyPolicy'),
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
                VyroListRow(
                  icon: Icons.ios_share_outlined,
                  title: t.get('exportData'),
                  subtitle: t.get('exportDataSubtitle'),
                  onTap: () => _export(context, services),
                ),
                VyroListRow(
                  icon: Icons.file_open_outlined,
                  title: t.get('importData'),
                  subtitle: t.get('importDataSubtitle'),
                  onTap: () => _import(context, services, settings),
                ),
                VyroListRow(
                  icon: Icons.delete_outline_rounded,
                  title: t.get('deleteAllData'),
                  subtitle: t.get('deleteAllSubtitle'),
                  destructive: true,
                  onTap: () => _deleteAll(context, services),
                ),
              ],
            ),
            const SizedBox(height: 24),
            VyroGroupedSection(
              header: 'VYRO',
              children: [
                VyroListRow(
                  icon: Icons.waving_hand_outlined,
                  iconColor: Theme.of(context).colorScheme.tertiary,
                  title: t.get('restartTutorial'),
                  onTap: () => Navigator.pushNamed(context, '/onboarding'),
                ),
                VyroListRow(
                  icon: Icons.widgets_outlined,
                  iconColor: Theme.of(context).colorScheme.tertiary,
                  title: t.get('design'),
                  subtitle: t.get('designSubtitle'),
                  onTap: () => Navigator.pushNamed(context, '/design-system'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _goalName(VyroStrings t, String goal) => t.get(switch (goal) {
    'strength' => 'goalStrength',
    'nutrition' => 'goalNutrition',
    _ => 'goalRoutine',
  });

  Future<void> _editProfile(
    BuildContext context,
    AppServices services,
    VyroProfile? profile,
  ) async {
    final t = stringsOf(context);
    final name = TextEditingController(text: profile?.name ?? '');
    final kcal = TextEditingController(
      text: (profile?.calorieGoal ?? 2200).round().toString(),
    );
    final protein = TextEditingController(
      text: (profile?.proteinGoal ?? 140).round().toString(),
    );
    final carbs = TextEditingController(
      text: (profile?.carbsGoal ?? 260).round().toString(),
    );
    final fat = TextEditingController(
      text: (profile?.fatGoal ?? 75).round().toString(),
    );
    var goal = profile?.goal ?? 'routine';
    var activity = profile?.activityLevel ?? 'moderate';
    var diet = profile?.dietaryChoice ?? 'none';
    var experience = profile?.workoutExperience ?? 'beginner';
    var days = profile?.trainingDays ?? 3;
    final equipment = <String>{
      ...(profile?.availableEquipment ?? ['bodyweight', 'dumbbells', 'cable']),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t.get('editProfile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: t.get('name')),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: goal,
                  decoration: InputDecoration(labelText: t.get('goalPrompt')),
                  items: ['strength', 'nutrition', 'routine']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_goalName(t, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => goal = value);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: activity,
                  decoration: InputDecoration(
                    labelText: t.get('activityLevel'),
                  ),
                  items: ['low', 'moderate', 'high']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(t.get('activity_$value')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => activity = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: diet,
                  decoration: InputDecoration(
                    labelText: t.get('dietaryChoice'),
                  ),
                  items: ['none', 'vegetarian', 'vegan']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(t.get('diet_$value')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => diet = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: experience,
                  decoration: InputDecoration(
                    labelText: t.get('workoutExperience'),
                  ),
                  items: ['beginner', 'intermediate']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(t.get('experience_$value')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => experience = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: days.clamp(1, 7),
                  decoration: InputDecoration(labelText: t.get('trainingDays')),
                  items: List.generate(7, (i) => i + 1)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => days = value);
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.get('availableEquipment')),
                ),
                Wrap(
                  spacing: 4,
                  children: ['bodyweight', 'dumbbells', 'cable']
                      .map(
                        (value) => FilterChip(
                          label: Text(t.get('equipment_$value')),
                          selected: equipment.contains(value),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              equipment.add(value);
                            } else {
                              equipment.remove(value);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                _numberField(kcal, t.get('calorieTarget'), 'kcal'),
                _numberField(protein, t.get('protein'), 'g'),
                _numberField(carbs, t.get('carbs'), 'g'),
                _numberField(fat, t.get('fat'), 'g'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.get('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      double parse(TextEditingController c, double fallback) {
        final value = double.tryParse(c.text.trim());
        return value != null && value.isFinite && value > 0 && value <= 100000
            ? value
            : fallback;
      }

      await services.database.saveUserProfile(
        (profile ?? const VyroProfile()).copyWith(
          name: name.text.trim(),
          goal: goal,
          activityLevel: activity,
          dietaryChoice: diet,
          workoutExperience: experience,
          availableEquipment: equipment.isEmpty
              ? ['bodyweight']
              : equipment.toList(),
          trainingDays: days,
          calorieGoal: parse(kcal, profile?.calorieGoal ?? 2200),
          proteinGoal: parse(protein, profile?.proteinGoal ?? 140),
          carbsGoal: parse(carbs, profile?.carbsGoal ?? 260),
          fatGoal: parse(fat, profile?.fatGoal ?? 75),
          onboardingCompleted: true,
        ),
      );
      if (context.mounted) {
        _reload();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.get('savedLocally'))));
      }
    }
    name.dispose();
    kcal.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix,
  ) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );

  Future<void> _export(BuildContext context, AppServices services) async {
    final t = stringsOf(context);
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(await services.database.exportAllData());
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('exportData')),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.get('exportCopyInstruction')),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.get('close')),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.copy),
            label: Text(t.get('copyExport')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context, AppServices services) async {
    final t = stringsOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('deleteAllData')),
        content: Text(t.get('deleteAllConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.get('delete')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await services.database.clearUserData();
      if (!context.mounted) return;
      final settings = SettingsScope.of(context);
      settings.resetAfterDeletion();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _generatePlan(BuildContext context, AppServices services) async {
    final t = stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('generatePlan')),
        content: Text(t.get('generatePlanConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.get('continue')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await services.workoutRepository.createPlanFromProfile();
    if (!context.mounted) return;
    _reload();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.get('planCreated'))));
  }

  Future<void> _import(
    BuildContext context,
    AppServices services,
    AppSettings settings,
  ) async {
    final t = stringsOf(context);
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('importData')),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.get('importPasteInstruction')),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 8,
                maxLines: 14,
                maxLength: 5000000,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: t.get('importPasteHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(t.get('continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != 'vyro-local-export-v1') {
        throw const FormatException();
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.get('importInvalid'))));
      return;
    }
    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('importData')),
        content: Text(t.get('importReplaceConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.get('importReplace')),
          ),
        ],
      ),
    );
    if (replace != true) return;
    try {
      await services.database.importAllData(decoded);
      await settings.refreshProfile();
      if (!context.mounted) return;
      _reload();
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.get('importSuccess'))));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.get('importInvalid'))));
    }
  }
}
