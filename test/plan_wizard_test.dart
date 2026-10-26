import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/core/ui/vyro_ui.dart';
import 'package:vyro/features/workouts/plan_wizard_page.dart';

class _NoLlm implements OnDeviceLlm {
  @override
  Future<LlmStatus> status() async => LlmStatus.unavailable;

  @override
  Future<LlmStatus> download() async => LlmStatus.unavailable;

  @override
  Future<String> generate(String prompt) async => '';
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppServicesScope(
        services: AppServices(database: database, llm: _NoLlm()),
        child: MaterialApp(
          theme: VyroTheme.dark,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PlanWizardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continueStep(WidgetTester tester) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('duration of inactivity only appears after some experience', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Qual é o teu objetivo principal?'), findsOneWidget);
    await tester.tap(find.text('Ganhar músculo'));
    await tester.pumpAndSettle();
    await continueStep(tester);

    await tester.tap(find.text('Nunca treinei'));
    await tester.pumpAndSettle();
    expect(find.text('Estiveste parado(a) há quanto tempo?'), findsNothing);

    await tester.tap(find.text('Menos de 6 meses'));
    await tester.pumpAndSettle();
    expect(find.text('Estiveste parado(a) há quanto tempo?'), findsOneWidget);
  });

  testWidgets('optional steps can be skipped', (tester) async {
    await open(tester);
    // goal, experience, days (default days already picked), duration,
    // location, equipment, then limitations, which is skippable.
    for (var i = 0; i < 6; i++) {
      await continueStep(tester);
    }
    expect(
      find.text('Tens alguma limitação ou dor em alguma zona?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    expect(find.text('Queres dar mais atenção a alguma zona?'), findsOneWidget);
  });

  testWidgets(
    'equipment details follow the place and dumbbell weight shows only with dumbbells',
    (tester) async {
      await open(tester);
      for (var i = 0; i < 4; i++) {
        await continueStep(tester);
      }
      // At the location step choose home: no barbell offered.
      await tester.tap(find.text('Casa'));
      await tester.pumpAndSettle();
      await continueStep(tester);
      expect(find.text('Barra olímpica e discos'), findsNothing);
      expect(find.text('Elásticos'), findsOneWidget);
      // Dumbbells are selected by default, so the weight field is visible.
      expect(find.text('Peso máximo dos halteres (opcional)'), findsOneWidget);
      // Deselecting dumbbells hides the weight field again.
      await tester.tap(find.text('Halteres'));
      await tester.pumpAndSettle();
      expect(find.text('Peso máximo dos halteres (opcional)'), findsNothing);
      await tester.tap(find.text('Halteres'));
      await tester.pumpAndSettle();
      expect(find.text('Peso máximo dos halteres (opcional)'), findsOneWidget);
    },
  );

  testWidgets('under 18 blocks the wizard with a clear message', (
    tester,
  ) async {
    await open(tester);
    // Go to the context step (index 11): tap continue until it appears.
    for (var i = 0; i < 11; i++) {
      final skip = find.text('Saltar');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
      } else {
        await continueStep(tester);
      }
      await tester.pumpAndSettle();
    }
    expect(find.text('Contexto opcional'), findsOneWidget);
    await tester.tap(find.text('Menos de 18 anos'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Ainda não geramos planos para menores de 18 anos. Fala com um adulto ou com um profissional de desporto.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<VyroPrimaryButton>(
      find.byType(VyroPrimaryButton),
    );
    expect(button.onPressed, isNull);
  });
}
