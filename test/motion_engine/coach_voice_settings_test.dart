import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/feedback_engine/coach_voice_settings.dart';
import 'package:vyro/features/motion_engine/feedback_engine/voice_coach.dart';

void main() {
  group('CoachVoice.fromMap', () {
    test('reads the Android map fields of a local voice', () {
      final voice = CoachVoice.fromMap({
        'name': 'pt-pt-x-ptd-local',
        'locale': 'pt-PT',
        'quality': 'very high',
        'latency': 'normal',
        'network_required': '0',
        'features': 'embeddedSynthesis',
      });
      expect(voice, isNotNull);
      expect(voice!.quality, 'very high');
      expect(voice.networkRequired, isFalse);
      expect(voice.notInstalled, isFalse);
      expect(voice.isLocal, isTrue);
    });

    test('a voice listed but not installed is not local', () {
      final voice = CoachVoice.fromMap({
        'name': 'pt-pt-x-ptd-local',
        'locale': 'pt-PT',
        'network_required': '0',
        'features': 'embeddedSynthesis\tnotInstalled',
      });
      expect(voice!.notInstalled, isTrue);
      expect(voice.isLocal, isFalse);
    });

    test('a feature that mentions the network makes the voice online', () {
      final voice = CoachVoice.fromMap({
        'name': 'pt-pt-x-ptd-local',
        'locale': 'pt-PT',
        'network_required': '0',
        'features': 'networkTimeoutMs\tnetworkRetriesCount',
      });
      expect(voice!.networkRequired, isTrue);
      expect(voice.isLocal, isFalse);
    });

    test('marks network voices from the flag, the name or the features', () {
      expect(
        CoachVoice.fromMap({
          'name': 'a',
          'locale': 'pt-PT',
          'network_required': '1',
        })!.networkRequired,
        isTrue,
      );
      expect(
        CoachVoice.fromMap({
          'name': 'pt-pt-x-network',
          'locale': 'pt-PT',
        })!.networkRequired,
        isTrue,
      );
      expect(
        CoachVoice.fromMap({
          'name': 'b',
          'locale': 'pt-PT',
          'network_required': true,
        })!.networkRequired,
        isTrue,
      );
    });

    test('returns null without a name or locale', () {
      expect(CoachVoice.fromMap({'name': 'x'}), isNull);
      expect(CoachVoice.fromMap({'locale': 'pt-PT'}), isNull);
      expect(CoachVoice.fromMap({'name': '  ', 'locale': 'pt-PT'}), isNull);
      expect(CoachVoice.fromMap('pt-PT'), isNull);
    });

    test('parseList handles null and non-list values', () {
      expect(CoachVoice.parseList(null), isEmpty);
      expect(CoachVoice.parseList('voices'), isEmpty);
      final parsed = CoachVoice.parseList([
        {'name': 'a', 'locale': 'pt-PT'},
        'bad',
        {'name': 'b'},
      ]);
      expect(parsed.map((v) => v.name), ['a']);
    });
  });

  group('localVoicesFor', () {
    final voices = CoachVoice.parseList([
      {'name': 'br-local', 'locale': 'pt-BR'},
      {'name': 'pt-pt-b', 'locale': 'pt-PT'},
      {'name': 'pt-pt-net', 'locale': 'pt-PT', 'network_required': '1'},
      {'name': 'en-us-a', 'locale': 'en-US'},
      {'name': 'pt-pt-a', 'locale': 'pt-PT'},
      {'name': 'pt-pt-a', 'locale': 'pt-PT'},
      {'name': 'pt-pt-missing', 'locale': 'pt-PT', 'features': 'notInstalled'},
      {'name': 'en-gb-a', 'locale': 'en-GB'},
    ]);

    test(
      'Portuguese: pt-PT first, then other pt locales, no network voices',
      () {
        final result = localVoicesFor(voices, VoiceLanguage.portuguese);
        expect(result.map((v) => v.name), ['pt-pt-a', 'pt-pt-b', 'br-local']);
      },
    );

    test('English: only en locales', () {
      final result = localVoicesFor(voices, VoiceLanguage.english);
      expect(result.map((v) => v.name), ['en-gb-a', 'en-us-a']);
    });

    test('empty input gives an empty list', () {
      expect(localVoicesFor(const [], VoiceLanguage.portuguese), isEmpty);
    });
  });

  group('coachVoiceLabel', () {
    test(
      'Portugal voice in Portuguese, with gender and quality when known',
      () {
        const voice = CoachVoice(
          name: 'x',
          locale: 'pt-PT',
          gender: 'female',
          quality: 'very high',
        );
        expect(
          coachVoiceLabel(voice, index: 1, english: false),
          'Voz 1 · Portugal · feminina · qualidade alta',
        );
        expect(
          coachVoiceLabel(voice, index: 1, english: true),
          'Voice 1 · Portugal · female · high quality',
        );
      },
    );

    test('omits gender and quality when the engine does not report them', () {
      const voice = CoachVoice(name: 'x', locale: 'pt-PT');
      expect(
        coachVoiceLabel(voice, index: 2, english: false),
        'Voz 2 · Portugal',
      );
    });

    test('Brazilian Portuguese is labelled as such', () {
      const voice = CoachVoice(name: 'x', locale: 'pt-BR');
      expect(
        coachVoiceLabel(voice, index: 3, english: false),
        'Voz 3 · Português (Brasil)',
      );
    });

    test('unknown locale falls back to its tag', () {
      const voice = CoachVoice(name: 'x', locale: 'de-DE');
      expect(coachVoiceLabel(voice, index: 1, english: false), 'Voz 1 · de-DE');
    });
  });

  group('CoachVoiceSettings', () {
    test('defaults when nothing is stored', () {
      final settings = CoachVoiceSettings.fromJson(null);
      expect(settings.hasVoice, isFalse);
      expect(settings.rate, CoachVoiceSettings.defaultRate);
      expect(settings.pitch, CoachVoiceSettings.defaultPitch);
      expect(settings.llmPhrases, isNull);
    });

    test('round-trips through JSON', () {
      const settings = CoachVoiceSettings(
        voiceName: 'pt-pt-x-ptd-local',
        voiceLocale: 'pt-PT',
        rate: 0.65,
        pitch: 1.2,
        llmPhrases: false,
      );
      final back = CoachVoiceSettings.fromJson(settings.toJson());
      expect(back.voiceName, 'pt-pt-x-ptd-local');
      expect(back.voiceLocale, 'pt-PT');
      expect(back.rate, 0.65);
      expect(back.pitch, 1.2);
      expect(back.llmPhrases, isFalse);
      expect(back.voiceMap, {'name': 'pt-pt-x-ptd-local', 'locale': 'pt-PT'});
    });

    test('malformed or wrong-typed values fall back to defaults', () {
      expect(CoachVoiceSettings.fromJson('not json').rate, 0.5);
      expect(CoachVoiceSettings.fromJson('[1, 2]').hasVoice, isFalse);
      final odd = CoachVoiceSettings.fromJson(
        '{"voiceName": 7, "voiceLocale": "", "rate": "fast", '
        '"pitch": null, "llmPhrases": "yes"}',
      );
      expect(odd.hasVoice, isFalse);
      expect(odd.rate, CoachVoiceSettings.defaultRate);
      expect(odd.pitch, CoachVoiceSettings.defaultPitch);
      expect(odd.llmPhrases, isNull);
    });

    test('numbers are clamped to the engine range', () {
      final settings = CoachVoiceSettings.fromJson('{"rate": 9, "pitch": -4}');
      expect(settings.rate, 1.0);
      expect(settings.pitch, CoachVoiceSettings.enginePitchMin);
      final low = CoachVoiceSettings.fromJson('{"rate": -2}');
      expect(low.rate, 0.0);
    });

    test('copyWith can clear the voice and clamps new values', () {
      const base = CoachVoiceSettings(voiceName: 'a', voiceLocale: 'pt-PT');
      final cleared = base.copyWith(clearVoice: true);
      expect(cleared.hasVoice, isFalse);
      expect(cleared.voiceMap, isNull);
      expect(base.copyWith(pitch: 5).pitch, CoachVoiceSettings.enginePitchMax);
      expect(
        base.copyWith(rate: double.nan).rate,
        CoachVoiceSettings.defaultRate,
      );
    });

    test('selects matches name and locale case-insensitively', () {
      const settings = CoachVoiceSettings(
        voiceName: 'pt-pt-a',
        voiceLocale: 'pt-PT',
      );
      expect(
        settings.selects(const CoachVoice(name: 'pt-pt-a', locale: 'pt-pt')),
        isTrue,
      );
      expect(
        settings.selects(const CoachVoice(name: 'pt-pt-b', locale: 'pt-PT')),
        isFalse,
      );
    });
  });

  group('CoachVoicePreferences', () {
    test('saves and loads through the key/value store', () async {
      final store = <String, String>{};
      final prefs = CoachVoicePreferences(
        read: (key) async => store[key],
        write: (key, value) async => store[key] = value,
      );
      expect(await prefs.load(), isA<CoachVoiceSettings>());
      final saved = await prefs.save(
        const CoachVoiceSettings(voiceName: 'a', voiceLocale: 'pt-PT'),
      );
      expect(saved, isTrue);
      expect(store.keys, [CoachVoicePreferences.settingsKey]);
      final loaded = await prefs.load();
      expect(loaded.voiceName, 'a');
    });

    test(
      'unreadable store gives defaults and failed writes return false',
      () async {
        final prefs = CoachVoicePreferences(
          read: (_) async => throw StateError('boom'),
          write: (_, _) async => throw StateError('boom'),
        );
        expect((await prefs.load()).hasVoice, isFalse);
        expect(await prefs.save(const CoachVoiceSettings()), isFalse);
      },
    );
  });
}
