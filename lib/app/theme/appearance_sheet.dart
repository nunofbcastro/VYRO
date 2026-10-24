import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import 'vyro_chrome.dart';

Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.get('appearance'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                const AppearanceChoices(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme + language choices shared by the settings sheet and the onboarding
/// wizard. Changes apply immediately and are persisted by [AppSettings].
class AppearanceChoices extends StatelessWidget {
  const AppearanceChoices({
    super.key,
    this.showLabels = false,
    this.compact = false,
  });

  final bool showLabels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final settings = SettingsScope.of(context);
    Widget gap() => SizedBox(height: compact ? 8 : 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabels) ...[
          Text(
            t.get('appearance'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        VyroChoiceCard(
          icon: Icons.dark_mode_outlined,
          title: t.get('dark'),
          subtitle: compact ? null : t.get('themeDarkHint'),
          selected: settings.themeMode == ThemeMode.dark,
          onTap: () => settings.setTheme(ThemeMode.dark),
        ),
        gap(),
        VyroChoiceCard(
          icon: Icons.light_mode_outlined,
          title: t.get('light'),
          subtitle: compact ? null : t.get('themeLightHint'),
          selected: settings.themeMode == ThemeMode.light,
          onTap: () => settings.setTheme(ThemeMode.light),
        ),
        gap(),
        VyroChoiceCard(
          icon: Icons.brightness_auto_outlined,
          title: t.get('system'),
          subtitle: compact ? null : t.get('themeSystemHint'),
          selected: settings.themeMode == ThemeMode.system,
          onTap: () => settings.setTheme(ThemeMode.system),
        ),
        SizedBox(height: compact ? 22 : 26),
        Text(t.get('language'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        VyroChoiceCard(
          icon: Icons.translate_rounded,
          title: t.get('languagePt'),
          selected: settings.locale.languageCode == 'pt',
          onTap: () => settings.setLocale(const Locale('pt', 'PT')),
          trailing: const _LocaleTag(label: 'PT'),
        ),
        gap(),
        VyroChoiceCard(
          icon: Icons.language_rounded,
          title: t.get('languageEn'),
          selected: settings.locale.languageCode == 'en',
          onTap: () => settings.setLocale(const Locale('en')),
          trailing: const _LocaleTag(label: 'EN'),
        ),
      ],
    );
  }
}

class _LocaleTag extends StatelessWidget {
  const _LocaleTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Theme.of(context).textTheme.labelSmall?.color,
        ),
      ),
    );
  }
}
