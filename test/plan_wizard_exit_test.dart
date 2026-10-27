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

const _exitMessage = 'Sair sem guardar? As respostas desta sessão perdem-se.';

void main() {
  late AppDatabase database;
  late AppServices services;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    services = AppServices(database: database, llm: _NoLlm());
  });
  tearDown(() => database.close());

  /// Pushes the wizard over a base page so exits can be seen as pops.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: VyroTheme.dark,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanWizardPage()),
                  ),
                  child: const Text('BASE'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BASE'));
    await tester.pumpAndSettle();
    expect(find.text('Criar o teu plano'), findsOneWidget);
  }

  Future<void> continueStep(WidgetTester tester) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
  }

  testWidgets('X exits immediately when nothing changed', (tester) async {
    await open(tester);
    await tapClose(tester);
    expect(find.text('BASE'), findsOneWidget);
    expect(find.text(_exitMessage), findsNothing);
  });

  testWidgets('X with a changed answer asks first', (tester) async {
    await open(tester);
    await tester.tap(find.text('Perder gordura'));
    await tester.pumpAndSettle();
    await tapClose(tester);
    expect(find.text(_exitMessage), findsOneWidget);
    expect(find.text('Criar o teu plano'), findsOneWidget);
    expect(find.text('BASE'), findsNothing);
  });

  testWidgets('Continuar a editar keeps the wizard open', (tester) async {
    await open(tester);
    await tester.tap(find.text('Perder gordura'));
    await tester.pumpAndSettle();
    await tapClose(tester);
    await tester.tap(find.text('Continuar a editar'));
    await tester.pumpAndSettle();
    expect(find.text(_exitMessage), findsNothing);
    expect(find.text('Criar o teu plano'), findsOneWidget);
    expect(find.text('BASE'), findsNothing);
  });

  testWidgets('Sair leaves the wizard with a single pop', (tester) async {
    await open(tester);
    await tester.tap(find.text('Perder gordura'));
    await tester.pumpAndSettle();
    await tapClose(tester);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Criar o teu plano'), findsNothing);
    // One pop only: the base page underneath is still there.
    expect(find.text('BASE'), findsOneWidget);
  });

  testWidgets('system back on the first step exits', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Criar o teu plano'), findsNothing);
    expect(find.text('BASE'), findsOneWidget);
  });

  testWidgets('system back on step 3 goes to step 2', (tester) async {
    await open(tester);
    await continueStep(tester);
    await continueStep(tester);
    expect(find.text('Nunca treinei'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Nunca treinei'), findsOneWidget);
    expect(find.text('BASE'), findsNothing);
    expect(find.text('Criar o teu plano'), findsOneWidget);
  });

  testWidgets('preview cancel leaves the existing plan untouched', (
    tester,
  ) async {
    final repository = services.workoutRepository;
    final before = await tester.runAsync(() async {
      final plan = await repository.loadOrCreatePlan();
      final prefs = await repository.loadPreferences();
      return (
        title: plan.plan.title,
        days: plan.days.length,
        prefs: prefs.encode(),
      );
    });

    await open(tester);
    for (var i = 0; i < 13; i++) {
      await continueStep(tester);
    }
    await tester.tap(find.text('Gerar plano'));
    // Rule generation reads the database, which needs real time to finish.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardar plano'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(_exitMessage), findsOneWidget);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('BASE'), findsOneWidget);

    final after = await tester.runAsync(() async {
      final plan = await repository.reloadPlan();
      final prefs = await repository.loadPreferences();
      return (
        title: plan.plan.title,
        days: plan.days.length,
        prefs: prefs.encode(),
      );
    });
    expect(after, before);
  });
}
