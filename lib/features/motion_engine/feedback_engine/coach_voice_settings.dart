import 'dart:convert';

import 'voice_coach.dart';

/// One text-to-speech voice reported by the platform engine.
///
/// Android reports `name`, `locale`, `quality`, `latency`, `network_required`
/// (`'1'`/`'0'`) and `features` (tab-separated). iOS reports `name`, `locale`,
/// `quality`, `gender` and `identifier`.
class CoachVoice {
  const CoachVoice({
    required this.name,
    required this.locale,
    this.quality,
    this.gender,
    this.identifier,
    this.networkRequired = false,
    this.notInstalled = false,
  });

  final String name;
  final String locale;
  final String? quality;
  final String? gender;
  final String? identifier;

  /// True when the engine streams speech from a server. Such voices are never
  /// offered: coach text must stay on the phone.
  final bool networkRequired;

  /// True when the engine lists the voice but its data is not downloaded.
  final bool notInstalled;

  /// Usable offline and already installed.
  bool get isLocal => !networkRequired && !notInstalled;

  /// Language code in lower case, for example `pt` for `pt-PT`.
  String get languageCode => _languageCodeOf(locale);

  /// Map passed back to `FlutterTts.setVoice`.
  Map<String, String> get voiceMap => {
    'name': name,
    'locale': locale,
    if (identifier != null) 'identifier': identifier!,
  };

  bool sameAs(CoachVoice other) =>
      name == other.name && locale.toLowerCase() == other.locale.toLowerCase();

  /// Parses one map from `FlutterTts.getVoices`. Returns null when the entry
  /// has no name or locale.
  static CoachVoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = _text(raw['name']);
    final locale = _text(raw['locale']);
    if (name == null || locale == null) return null;
    final features = _text(raw['features']) ?? '';
    final featureList = features
        .split(RegExp(r'[\t,;]'))
        .map((f) => f.trim().toLowerCase())
        .where((f) => f.isNotEmpty)
        .toList();
    final lowerName = name.toLowerCase();
    // A voice is treated as online when the engine says so, when its name says
    // "network", or when a feature mentions the network. Doubtful voices are
    // excluded because the text must never leave the phone.
    final network =
        _truthy(raw['network_required']) ||
        lowerName.contains('network') ||
        featureList.any((f) => f.contains('network'));
    return CoachVoice(
      name: name,
      locale: locale,
      quality: _text(raw['quality']),
      gender: _text(raw['gender']),
      identifier: _text(raw['identifier']),
      networkRequired: network,
      notInstalled: featureList.any((f) => f == 'notinstalled'),
    );
  }

  /// Parses the whole list returned by `FlutterTts.getVoices`. Anything that
  /// is not a list (null on unsupported platforms) gives an empty list.
  static List<CoachVoice> parseList(Object? raw) {
    if (raw is! List) return const [];
    final voices = <CoachVoice>[];
    for (final entry in raw) {
      final voice = fromMap(entry);
      if (voice != null) voices.add(voice);
    }
    return voices;
  }
}

/// Local voices for [language], best first: Portuguese from Portugal, then
/// other Portuguese locales; English voices sorted by locale.
///
/// Voices that need the network, and voices that are not installed, are
/// removed. Duplicates (same name and locale) are dropped.
List<CoachVoice> localVoicesFor(
  Iterable<CoachVoice> voices,
  VoiceLanguage language,
) {
  final code = language == VoiceLanguage.portuguese ? 'pt' : 'en';
  final seen = <String>{};
  final result = <CoachVoice>[
    for (final voice in voices)
      if (voice.isLocal &&
          voice.languageCode == code &&
          seen.add('${voice.name}|${voice.locale.toLowerCase()}'))
        voice,
  ];
  result.sort((a, b) {
    final rank = _rank(a.locale).compareTo(_rank(b.locale));
    if (rank != 0) return rank;
    final byLocale = a.locale.toLowerCase().compareTo(b.locale.toLowerCase());
    return byLocale != 0 ? byLocale : a.name.compareTo(b.name);
  });
  return result;
}

/// Friendly label such as `Voz 1 · Portugal`. Gender and quality are added
/// only when the engine reports them. [index] is 1-based.
String coachVoiceLabel(
  CoachVoice voice, {
  required int index,
  required bool english,
}) {
  final parts = <String>[
    '${english ? 'Voice' : 'Voz'} $index',
    _localeLabel(voice.locale, english: english),
  ];
  final gender = _genderLabel(voice.gender, english: english);
  if (gender != null) parts.add(gender);
  final quality = _qualityLabel(voice.quality, english: english);
  if (quality != null) parts.add(quality);
  return parts.join(' · ');
}

/// Settings chosen in the "Voz do treinador" sheet. Stored as one JSON value.
class CoachVoiceSettings {
  const CoachVoiceSettings({
    this.voiceName,
    this.voiceLocale,
    this.rate = defaultRate,
    this.pitch = defaultPitch,
    this.llmPhrases,
  });

  static const defaultRate = 0.5;
  static const defaultPitch = 1.0;

  /// Range offered by the sheet sliders.
  static const minRate = 0.3, maxRate = 0.8;
  static const minPitch = 0.7, maxPitch = 1.5;

  /// Range accepted by the engine (values outside are clamped on load).
  static const engineMinRate = 0.0, engineMaxRate = 1.0;
  static const enginePitchMin = 0.5, enginePitchMax = 2.0;

  final String? voiceName;
  final String? voiceLocale;

  /// Engine scale: 0.0 (slowest) to 1.0 (fastest); 0.5 is normal.
  final double rate;

  /// Engine scale: 1.0 is normal.
  final double pitch;

  /// Whether to ask the on-device model for encouragement phrases. Null means
  /// the default: on, but only when the model is available.
  final bool? llmPhrases;

  bool get hasVoice => voiceName != null && voiceLocale != null;

  /// Map for `FlutterTts.setVoice`, or null when no voice is chosen.
  Map<String, String>? get voiceMap =>
      hasVoice ? {'name': voiceName!, 'locale': voiceLocale!} : null;

  /// Pass [clearVoice] to forget the chosen voice.
  CoachVoiceSettings copyWith({
    String? voiceName,
    String? voiceLocale,
    bool clearVoice = false,
    double? rate,
    double? pitch,
    bool? llmPhrases,
  }) => CoachVoiceSettings(
    voiceName: clearVoice ? null : (voiceName ?? this.voiceName),
    voiceLocale: clearVoice ? null : (voiceLocale ?? this.voiceLocale),
    rate: _clampDouble(
      rate ?? this.rate,
      engineMinRate,
      engineMaxRate,
      defaultRate,
    ),
    pitch: _clampDouble(
      pitch ?? this.pitch,
      enginePitchMin,
      enginePitchMax,
      defaultPitch,
    ),
    llmPhrases: llmPhrases ?? this.llmPhrases,
  );

  /// True when the saved voice is the one [voice] describes.
  bool selects(CoachVoice voice) =>
      hasVoice &&
      voiceName == voice.name &&
      voiceLocale!.toLowerCase() == voice.locale.toLowerCase();

  String toJson() => jsonEncode({
    'v': 1,
    if (voiceName != null) 'voiceName': voiceName,
    if (voiceLocale != null) 'voiceLocale': voiceLocale,
    'rate': rate,
    'pitch': pitch,
    if (llmPhrases != null) 'llmPhrases': llmPhrases,
  });

  /// Reads a stored value. Missing, malformed or wrong-typed fields fall back
  /// to the defaults; numbers are clamped to the usable range.
  static CoachVoiceSettings fromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const CoachVoiceSettings();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const CoachVoiceSettings();
    }
    if (decoded is! Map) return const CoachVoiceSettings();
    final name = decoded['voiceName'];
    final locale = decoded['voiceLocale'];
    final llm = decoded['llmPhrases'];
    return CoachVoiceSettings(
      voiceName: name is String && name.isNotEmpty ? name : null,
      voiceLocale: locale is String && locale.isNotEmpty ? locale : null,
      rate: _clampDouble(
        _number(decoded['rate']),
        engineMinRate,
        engineMaxRate,
        defaultRate,
      ),
      pitch: _clampDouble(
        _number(decoded['pitch']),
        enginePitchMin,
        enginePitchMax,
        defaultPitch,
      ),
      llmPhrases: llm is bool ? llm : null,
    );
  }
}

/// Reads and writes [CoachVoiceSettings] through a key/value store. The app
/// passes the database preference methods; tests pass a map.
class CoachVoicePreferences {
  CoachVoicePreferences({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
  }) : _read = read,
       _write = write;

  static const settingsKey = 'coach_voice_settings_v1';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  /// Never throws: an unreadable store gives the defaults.
  Future<CoachVoiceSettings> load() async {
    try {
      return CoachVoiceSettings.fromJson(await _read(settingsKey));
    } catch (_) {
      return const CoachVoiceSettings();
    }
  }

  /// Returns false when the value could not be stored.
  Future<bool> save(CoachVoiceSettings settings) async {
    try {
      await _write(settingsKey, settings.toJson());
      return true;
    } catch (_) {
      return false;
    }
  }
}

double _clampDouble(double? value, double min, double max, double fallback) {
  if (value == null || !value.isFinite) return fallback;
  return value.clamp(min, max).toDouble();
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _truthy(Object? value) =>
    value == true ||
    value == 1 ||
    (value is String &&
        const {'1', 'true', 'yes'}.contains(value.trim().toLowerCase()));

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

String _languageCodeOf(String locale) {
  final parts = locale.split(RegExp(r'[-_]'));
  return parts.isEmpty ? '' : parts.first.toLowerCase();
}

/// Sort rank: pt-PT first, other Portuguese next, then everything else.
int _rank(String locale) {
  final tag = locale.toLowerCase().replaceAll('_', '-');
  if (tag == 'pt-pt' || tag.startsWith('pt-pt-')) return 0;
  if (_languageCodeOf(tag) == 'pt') return 1;
  return 2;
}

String _localeLabel(String locale, {required bool english}) {
  final tag = locale.replaceAll('_', '-');
  final lower = tag.toLowerCase();
  if (lower == 'pt-pt' || lower.startsWith('pt-pt-')) return 'Portugal';
  if (lower == 'pt-br' || lower.startsWith('pt-br-')) {
    return english ? 'Portuguese (Brazil)' : 'Português (Brasil)';
  }
  if (lower.startsWith('pt')) return english ? 'Portuguese' : 'Português';
  if (lower == 'en-us' || lower.startsWith('en-us-')) {
    return english ? 'English (US)' : 'Inglês (EUA)';
  }
  if (lower == 'en-gb' || lower.startsWith('en-gb-')) {
    return english ? 'English (UK)' : 'Inglês (Reino Unido)';
  }
  if (lower == 'en-au' || lower.startsWith('en-au-')) {
    return english ? 'English (Australia)' : 'Inglês (Austrália)';
  }
  if (lower.startsWith('en')) return english ? 'English' : 'Inglês';
  return tag;
}

String? _genderLabel(String? gender, {required bool english}) {
  switch (gender?.trim().toLowerCase()) {
    case 'female':
      return english ? 'female' : 'feminina';
    case 'male':
      return english ? 'male' : 'masculina';
    default:
      return null;
  }
}

String? _qualityLabel(String? quality, {required bool english}) {
  final q = quality?.trim().toLowerCase();
  if (q == null || q.isEmpty) return null;
  if (q == 'very high' || q == 'high' || q == 'premium') {
    return english ? 'high quality' : 'qualidade alta';
  }
  if (q == 'enhanced') return english ? 'enhanced' : 'melhorada';
  if (q == 'normal' || q == 'default') {
    return english ? 'standard quality' : 'qualidade normal';
  }
  if (q == 'low' || q == 'very low') {
    return english ? 'low quality' : 'qualidade baixa';
  }
  return null;
}
