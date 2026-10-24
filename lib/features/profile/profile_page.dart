import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final settings = SettingsScope.of(context);
    return ContentPage(
      showDemo: true,
      title: t.get('profile'),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 29,
                  child: Icon(Icons.person_outline, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Morgan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'alex@example.com · ${t.get('demo').toLowerCase()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined),
              ],
            ),
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
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(t.get('dark')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(t.get('light')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(t.get('system')),
                    ),
                  ],
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
            subtitle: Text(t.get('exportLater')),
          ),
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
  }
}
