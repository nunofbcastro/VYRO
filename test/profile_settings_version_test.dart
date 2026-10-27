import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/core/platform/app_version.dart';
import 'package:vyro/features/profile/profile_settings_page.dart';

const _fakeVersion = AppVersion(version: '0.6.10', buildNumber: '18');

void main() {
  late AppDatabase database;
  late List<String> copied;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppVersionLoader? loader,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = AppServices(database: database);
    final settings = AppSettings(services);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScope(
            settings: settings,
            child: ProfileSettingsPage(
              appVersionLoader: loader ?? () async => _fakeVersion,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> scrollToAbout(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('shows the faked version in the About section', (tester) async {
    await pumpSettings(tester);

    final versionRow = find.text('Versão 0.6.10 (18)');
    await scrollToAbout(tester, versionRow);
    expect(find.text('SOBRE A VYRO'), findsOneWidget);
    expect(versionRow, findsOneWidget);
  });

  testWidgets('tapping the version row copies the bug-report label', (
    tester,
  ) async {
    await pumpSettings(tester);

    final versionRow = find.text('Versão 0.6.10 (18)');
    await scrollToAbout(tester, versionRow);
    await tester.tap(versionRow);
    await settle(tester);

    expect(copied, ['VYRO 0.6.10 (18)']);
    expect(find.text('Versão copiada'), findsOneWidget);
  });

  testWidgets('long-pressing the version row copies the same label', (
    tester,
  ) async {
    await pumpSettings(tester);

    final versionRow = find.text('Versão 0.6.10 (18)');
    await scrollToAbout(tester, versionRow);
    await tester.longPress(versionRow);
    await settle(tester);

    expect(copied, ['VYRO 0.6.10 (18)']);
    expect(find.text('Versão copiada'), findsOneWidget);
  });

  testWidgets('settings has no GitHub releases row', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Ver versões no GitHub'), findsNothing);
    expect(find.text('View versions on GitHub'), findsNothing);
    expect(find.byKey(const ValueKey('github-releases-row')), findsNothing);
    expect(find.textContaining('github'), findsNothing);
  });

  testWidgets('shows an unknown version and disables copying on failure', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      loader: () async => throw StateError('no platform info'),
    );

    final unknownRow = find.text('Versão Desconhecida');
    await scrollToAbout(tester, unknownRow);
    expect(unknownRow, findsOneWidget);
    await tester.tap(unknownRow);
    await settle(tester);

    expect(copied, isEmpty);
  });
}
