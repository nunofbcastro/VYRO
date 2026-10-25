import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_services.dart';
import '../core/database/app_database.dart';
import 'l10n/strings.dart';
import 'launch_actions.dart';
import 'root_gate.dart';
import 'router/app_router.dart';
import 'theme/vyro_theme.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this.services);
  final AppServices services;
  Locale locale = const Locale('pt', 'PT');
  ThemeMode themeMode = ThemeMode.dark;
  VyroProfile? profile;
  Object? error;
  bool ready = false;

  bool get onboardingCompleted => profile?.onboardingCompleted ?? false;

  Future<void> load(AppServices services) async {
    ready = false;
    error = null;
    notifyListeners();
    try {
      final stored = await services.database.getUserProfile();
      profile = stored;
      locale = stored?.locale == 'en'
          ? const Locale('en')
          : const Locale('pt', 'PT');
      themeMode = switch (stored?.theme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (caught) {
      error = caught;
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  /// Re-reads the profile after onboarding, import or deletion. The root gate
  /// listens to this notifier, so finishing onboarding swaps the tree to the
  /// app shell without an extra navigation call.
  Future<void> refreshProfile() async {
    final stored = await services.database.getUserProfile();
    profile = stored;
    locale = stored?.locale == 'en'
        ? const Locale('en')
        : const Locale('pt', 'PT');
    themeMode = switch (stored?.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    error = null;
    notifyListeners();
  }

  void setLocale(Locale value) {
    locale = value;
    profile = (profile ?? const VyroProfile()).copyWith(
      locale: value.languageCode,
    );
    notifyListeners();
    // Persistence is best-effort: a storage failure must never break the UI
    // switch, and an unhandled future would surface as a console error.
    services.database
        .updateProfileLocale(value.languageCode)
        .catchError((_) {});
  }

  void setTheme(ThemeMode value) {
    themeMode = value;
    profile = (profile ?? const VyroProfile()).copyWith(
      theme: switch (value) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      },
    );
    notifyListeners();
    services.database
        .updateProfileTheme(switch (value) {
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
          ThemeMode.dark => 'dark',
        })
        .catchError((_) {});
  }

  void resetAfterDeletion() {
    profile = null;
    locale = const Locale('pt', 'PT');
    themeMode = ThemeMode.dark;
    notifyListeners();
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}

class VyroApp extends StatefulWidget {
  const VyroApp({super.key, required this.services});
  final AppServices services;

  @override
  State<VyroApp> createState() => _VyroAppState();
}

class _VyroAppState extends State<VyroApp> {
  late final AppSettings settings = AppSettings(widget.services);

  @override
  void initState() {
    super.initState();
    settings.load(widget.services);
    settings.addListener(_syncShortcuts);
    LaunchActions.init();
  }

  void _syncShortcuts() {
    if (settings.ready) LaunchActions.updateShortcuts(settings.locale);
  }

  @override
  void dispose() {
    settings.removeListener(_syncShortcuts);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => AppServicesScope(
      services: widget.services,
      child: SettingsScope(
        settings: settings,
        child: MaterialApp(
          navigatorKey: LaunchActions.navigatorKey,
          title: 'VYRO',
          debugShowCheckedModeBanner: false,
          theme: VyroTheme.light,
          darkTheme: VyroTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const VyroRoot(),
          onGenerateRoute: VyroRouter.onGenerateRoute,
        ),
      ),
    ),
  );
}
