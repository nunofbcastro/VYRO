import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/core/platform/orientation_lock.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_coach_page.dart';

const _portraitOnly = ['DeviceOrientation.portraitUp'];
const _allOrientations = [
  'DeviceOrientation.portraitUp',
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];

/// Records every `SystemChrome.setPreferredOrientations` call.
List<List<dynamic>> _recordOrientationCalls() {
  final calls = <List<dynamic>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments as List<dynamic>);
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

Widget _app(
  AppDatabase database, {
  GlobalKey<NavigatorState>? navigatorKey,
  Widget? home,
}) {
  return AppServicesScope(
    services: AppServices(database: database),
    child: MaterialApp(
      navigatorKey: navigatorKey,
      theme: VyroTheme.dark,
      locale: const Locale('pt', 'PT'),
      supportedLocales: VyroStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home ?? _coachPage(),
    ),
  );
}

MotionCoachPage _coachPage() => const MotionCoachPage(
  exerciseKey: 'goblet_squat',
  exerciseName: 'goblet_squat',
);

void main() {
  test('startup lock sends portraitUp only', () async {
    final calls = _recordOrientationCalls();
    await OrientationLock.lockPortrait();
    expect(calls, [_portraitOnly]);
  });

  test(
    'allow and release pair up: portrait returns only after the last hold',
    () async {
      final calls = _recordOrientationCalls();
      await OrientationLock.allowAllOrientations();
      await OrientationLock.allowAllOrientations();
      expect(OrientationLock.landscapeHolders, 2);
      await OrientationLock.releaseAllOrientations();
      expect(calls, [_allOrientations, _allOrientations]);
      await OrientationLock.releaseAllOrientations();
      expect(calls.last, _portraitOnly);
      expect(OrientationLock.landscapeHolders, 0);
    },
  );

  testWidgets(
    'camera page allows all orientations and restores portrait on dispose',
    (tester) async {
      final calls = _recordOrientationCalls();
      final database = AppDatabase(executor: NativeDatabase.memory());
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(database));
      await tester.pump();
      expect(calls, [_allOrientations]);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, [_allOrientations, _portraitOnly]);
      expect(OrientationLock.landscapeHolders, 0);

      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(database.close);
    },
  );

  testWidgets(
    'two camera pages: lower page removed first keeps landscape until the top one closes',
    (tester) async {
      final calls = _recordOrientationCalls();
      final database = AppDatabase(executor: NativeDatabase.memory());
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(database, navigatorKey: navigatorKey, home: const SizedBox()),
      );
      await tester.pump();

      final first = MaterialPageRoute<void>(builder: (_) => _coachPage());
      final second = MaterialPageRoute<void>(builder: (_) => _coachPage());
      navigatorKey.currentState!.push(first);
      await tester.pump();
      navigatorKey.currentState!.push(second);
      await tester.pump();
      expect(calls, [_allOrientations, _allOrientations]);
      expect(OrientationLock.landscapeHolders, 2);

      navigatorKey.currentState!.removeRoute(first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, [_allOrientations, _allOrientations]);
      expect(OrientationLock.landscapeHolders, 1);

      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls.last, _portraitOnly);
      expect(OrientationLock.landscapeHolders, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(database.close);
    },
  );
}
