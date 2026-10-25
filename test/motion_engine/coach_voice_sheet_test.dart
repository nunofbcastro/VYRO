import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/motion_engine/feedback_engine/coach_voice_settings.dart';
import 'package:vyro/features/motion_engine/workout_camera/coach_voice_sheet.dart';

class _StatusLlm implements OnDeviceLlm {
  _StatusLlm(this.value);
  final LlmStatus value;

  @override
  Future<LlmStatus> status() async => value;

  @override
  Future<LlmStatus> download() async => value;

  @override
  Future<String> generate(String prompt) async => '[]';
}

void main() {
  final store = <String, String>{};
  late CoachVoicePreferences prefs;
  late List<CoachVoiceSettings> previews;

  final voices = [
    const CoachVoice(
      name: 'pt-pt-a',
      locale: 'pt-PT',
      gender: 'female',
      quality: 'very high',
    ),
    const CoachVoice(name: 'pt-pt-b', locale: 'pt-PT'),
  ];

  setUp(() {
    store.clear();
    previews = [];
    prefs = CoachVoicePreferences(
      read: (key) async => store[key],
      write: (key, value) async => store[key] = value,
    );
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required List<CoachVoice> available,
    LlmStatus llm = LlmStatus.available,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('pt', 'PT'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CoachVoiceSheet(
            preferences: prefs,
            llm: _StatusLlm(llm),
            voiceSource: (language) async => available,
            previewer: (settings, language, sample) async {
              previews.add(settings);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists local voices with friendly labels', (tester) async {
    await pumpSheet(tester, available: voices);
    expect(
      find.text('Voice 1 · Portugal · female · high quality'),
      findsOneWidget,
    );
    expect(find.text('Voice 2 · Portugal'), findsOneWidget);
    expect(find.text('Phone default voice'), findsOneWidget);
  });

  testWidgets('selecting a voice saves it locally', (tester) async {
    await pumpSheet(tester, available: voices);
    await tester.tap(find.text('Voice 2 · Portugal'));
    await tester.pumpAndSettle();
    final saved = CoachVoiceSettings.fromJson(
      store[CoachVoicePreferences.settingsKey],
    );
    expect(saved.voiceName, 'pt-pt-b');
    expect(saved.voiceLocale, 'pt-PT');
  });

  testWidgets('listen previews the voice without saving it', (tester) async {
    await pumpSheet(tester, available: voices);
    await tester.tap(find.text('Listen').at(1));
    await tester.pumpAndSettle();
    expect(previews, hasLength(1));
    expect(previews.single.voiceName, 'pt-pt-a');
    expect(store.containsKey(CoachVoicePreferences.settingsKey), isFalse);
  });

  testWidgets('with no local voice it explains how to install one', (
    tester,
  ) async {
    await pumpSheet(tester, available: const []);
    expect(find.textContaining('no local English voices'), findsOneWidget);
    expect(
      find.textContaining('Voices that need the internet'),
      findsOneWidget,
    );
  });

  testWidgets('the phrase switch is disabled when the model is unavailable', (
    tester,
  ) async {
    await pumpSheet(tester, available: voices, llm: LlmStatus.unavailable);
    expect(find.textContaining('Not available on this phone'), findsOneWidget);
    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
    expect(switchTile.onChanged, isNull);
  });

  testWidgets('turning the phrase switch off is saved', (tester) async {
    await pumpSheet(tester, available: voices);
    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue, reason: 'on by default when available');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final saved = CoachVoiceSettings.fromJson(
      store[CoachVoicePreferences.settingsKey],
    );
    expect(saved.llmPhrases, isFalse);
  });

  testWidgets('Portuguese UI shows Portuguese labels', (tester) async {
    await pumpSheet(
      tester,
      available: voices,
      locale: const Locale('pt', 'PT'),
    );
    expect(find.text('Voz do treinador'), findsOneWidget);
    expect(
      find.text('Voz 1 · Portugal · feminina · qualidade alta'),
      findsOneWidget,
    );
    expect(find.text('Ouvir'), findsWidgets);
  });
}
