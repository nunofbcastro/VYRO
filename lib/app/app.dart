import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'router/app_router.dart';
import 'theme/vyro_theme.dart';

class AppSettings extends ChangeNotifier {
  Locale locale = const Locale('pt', 'PT');
  ThemeMode themeMode = ThemeMode.dark;

  void setLocale(Locale value) {
    locale = value;
    notifyListeners();
  }

  void setTheme(ThemeMode value) {
    themeMode = value;
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
  const VyroApp({super.key});

  @override
  State<VyroApp> createState() => _VyroAppState();
}

class _VyroAppState extends State<VyroApp> {
  final AppSettings settings = AppSettings();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => SettingsScope(
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
  );
}
