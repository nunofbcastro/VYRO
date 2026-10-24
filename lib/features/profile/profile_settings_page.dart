import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final services = AppServicesScope.of(context);
    final settings = SettingsScope.of(context);
    return FutureBuilder<VyroProfile?>(
      future: services.database.getUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return ContentPage(
          title: t.get('profile'),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  (profile?.name.trim().isNotEmpty ?? false)
                      ? profile!.name
                      : t.get('profileNotSet'),
                ),
                subtitle: Text(
                  '${t.get('goal')}: ${_goalName(t, profile?.goal ?? 'routine')}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editProfile(context, services, profile),
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle(t.get('settings')),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(t.get('appearance')),
                    trailing: DropdownButton<ThemeMode>(
                      value: settings.themeMode,
                      underline: const SizedBox(),
                      items: [ThemeMode.dark, ThemeMode.light, ThemeMode.system]
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(
                                t.get(switch (mode) {
                                  ThemeMode.dark => 'dark',
                                  ThemeMode.light => 'light',
                                  ThemeMode.system => 'system',
                                }),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) settings.setTheme(value);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(t.get('language')),
                    trailing: DropdownButton<String>(
                      value: settings.locale.languageCode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          settings.setLocale(
                            value == 'pt'
                                ? const Locale('pt', 'PT')
                                : const Locale('en'),
                          );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle(t.get('privacy')),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(t.get('localOnly')),
                subtitle: Text(t.get('privacyLocalExplanation')),
              ),
            ),
            const SizedBox(height: 8),
            ActionCard(
              icon: Icons.ios_share_outlined,
              title: t.get('exportData'),
              subtitle: t.get('exportDataSubtitle'),
              onTap: () => _export(context, services),
            ),
            const SizedBox(height: 8),
            ActionCard(
              icon: Icons.delete_outline,
              title: t.get('deleteAllData'),
              subtitle: t.get('deleteAllSubtitle'),
              onTap: () => _deleteAll(context, services),
            ),
            const SizedBox(height: 20),
            ActionCard(
              icon: Icons.palette,
              title: t.get('design'),
              subtitle: t.get('designSubtitle'),
              onTap: () => Navigator.pushNamed(context, '/design-system'),
            ),
            const SizedBox(height: 8),
            ActionCard(
              icon: Icons.waving_hand_outlined,
              title: t.get('onboarding'),
              onTap: () => Navigator.pushNamed(context, '/onboarding'),
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
      double parse(TextEditingController c, double fallback) =>
          double.tryParse(c.text.trim()) ?? fallback;
      await services.database.saveUserProfile(
        VyroProfile(
          name: name.text.trim(),
          goal: goal,
          calorieGoal: parse(kcal, profile?.calorieGoal ?? 2200),
          proteinGoal: parse(protein, profile?.proteinGoal ?? 140),
          carbsGoal: parse(carbs, profile?.carbsGoal ?? 260),
          fatGoal: parse(fat, profile?.fatGoal ?? 75),
          locale: profile?.locale ?? 'pt',
          theme: profile?.theme ?? 'dark',
        ),
      );
      if (context.mounted) Navigator.pushReplacementNamed(context, '/profile');
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
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }
}
