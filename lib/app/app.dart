import 'package:flutter/material.dart';

import 'app_services.dart';
import '../core/database/app_database.dart';
import 'l10n/strings.dart';
import 'router/app_router.dart';
import 'theme/vyro_theme.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this.services);
  final AppServices services;
  Locale locale = const Locale('pt', 'PT');
  ThemeMode themeMode = ThemeMode.dark;
  bool ready = false;

  Future<void> load(AppServices services) async {
    final db = services.database;
    final profile = await db.getUserProfile() ?? const VyroProfile();
    locale = profile.locale == 'en'
        ? const Locale('en')
        : const Locale('pt', 'PT');
    themeMode = switch (profile.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    ready = true;
    notifyListeners();
  }

  void setLocale(Locale value) {
    locale = value;
    notifyListeners();
    services.database.updateProfileLocale(value.languageCode);
  }

  void setTheme(ThemeMode value) {
    themeMode = value;
    notifyListeners();
    services.database.updateProfileTheme(switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    });
  }

  void resetAfterDeletion() {
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
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => AppServicesScope(
      services: widget.services,
      child: SettingsScope(
        settings: settings,
        child: MaterialApp(
          title: 'VYRO',
          debugShowCheckedModeBanner: false,
          theme: VyroTheme.light,
          darkTheme: VyroTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: VyroStrings.supportedLocales,
          onGenerateRoute: VyroRouter.onGenerateRoute,
          initialRoute: '/',
        ),
      ),
    ),
  );
}
