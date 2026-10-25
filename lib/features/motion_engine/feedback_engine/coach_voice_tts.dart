import 'package:flutter_tts/flutter_tts.dart';

import 'coach_voice_settings.dart';
import 'voice_coach.dart';

/// Applies [CoachVoiceSettings] to a [FlutterTts] engine and lists its voices.
/// Platform calls only; the rules live in `coach_voice_settings.dart`.
class CoachVoiceTts {
  CoachVoiceTts(this.tts);

  final FlutterTts tts;

  /// Local voices for [language] from the engine. Empty when the engine cannot
  /// list voices (unsupported platform or error).
  Future<List<CoachVoice>> loadLocalVoices(VoiceLanguage language) async {
    try {
      final raw = await tts.getVoices;
      return localVoicesFor(CoachVoice.parseList(raw), language);
    } catch (_) {
      return const [];
    }
  }

  /// Sets language, voice, rate and pitch in an order the engine accepts.
  /// The language is always set first (it is the fallback when no saved voice
  /// applies); the voice follows because some engines reset it on a language
  /// change. A saved voice for the other language is ignored.
  Future<void> apply(
    CoachVoiceSettings settings,
    VoiceLanguage language,
  ) async {
    final english = language == VoiceLanguage.english;
    try {
      await tts.setLanguage(english ? 'en-US' : 'pt-PT');
    } catch (_) {}
    final voice = settings.voiceMap;
    if (voice != null && _matchesLanguage(voice['locale']!, english)) {
      try {
        await tts.setVoice(voice);
      } catch (_) {
        // Voice missing or not supported: the language default stays.
      }
    }
    try {
      await tts.setSpeechRate(settings.rate);
    } catch (_) {}
    try {
      await tts.setPitch(settings.pitch);
    } catch (_) {}
  }

  static bool _matchesLanguage(String locale, bool english) {
    final code = locale.split(RegExp(r'[-_]')).first.toLowerCase();
    return code == (english ? 'en' : 'pt');
  }
}
