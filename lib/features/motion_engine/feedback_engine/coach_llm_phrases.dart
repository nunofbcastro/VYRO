import 'dart:convert';

import '../../../core/ai/on_device_llm.dart';
import '../exercise_analysis/exercise_analysis_engine.dart';
import 'voice_coach.dart';

/// Encouragement phrases and set commentary written by the on-device model
/// (Gemini Nano / Apple Intelligence). Never cloud, never a measurement.
///
/// The model only writes words. Every number, count and correctness claim is
/// decided by local code: phrases must contain no digits, and commentary may
/// only use the numbers that were given to the model. Anything that fails a
/// rule is dropped and the fixed templates are spoken instead.

/// Facts given to the model for the commentary. Also defines which numbers
/// the commentary may contain.
class CoachSetFacts {
  const CoachSetFacts({
    required this.exerciseName,
    required this.fullReps,
    required this.partialReps,
    required this.durationSeconds,
    this.holdSeconds = 0,
    this.targetReps,
    this.observations = const [],
  });

  factory CoachSetFacts.fromSummary(
    SetSummary summary, {
    required String exerciseName,
    int? targetReps,
    List<String> observations = const [],
  }) => CoachSetFacts(
    exerciseName: exerciseName,
    fullReps: summary.fullReps,
    partialReps: summary.partialReps,
    durationSeconds: summary.duration.inSeconds,
    holdSeconds: summary.holdTime.inSeconds,
    targetReps: targetReps,
    observations: observations,
  );

  final String exerciseName;
  final int fullReps;
  final int partialReps;
  final int durationSeconds;
  final int holdSeconds;
  final int? targetReps;

  /// Technique cues the set produced, already translated. Shown to the model
  /// as observations, not as an assessment.
  final List<String> observations;

  /// The only integers the commentary may contain.
  Set<int> get allowedNumbers => {
    fullReps,
    partialReps,
    fullReps + partialReps,
    durationSeconds,
    holdSeconds,
    ?targetReps,
  };
}

/// Limits for generated text.
class CoachPhraseRules {
  const CoachPhraseRules._();

  static const minLength = 2;
  static const maxPhraseLength = 60;
  static const maxWords = 8;
  static const maxBankSize = 15;

  /// Fewer valid phrases than this and the bank is discarded.
  static const minBankSize = 5;

  static const maxCommentaryLength = 200;
  static const maxCommentarySentences = 2;
}

/// Builds the request for the phrase bank. The model must answer with a JSON
/// array of strings only.
String buildPhraseBankPrompt({
  required String exerciseName,
  required int? targetReps,
  required VoiceLanguage language,
}) {
  final name = _promptSafe(exerciseName);
  final target = targetReps == null ? null : targetReps.toString();
  if (language == VoiceLanguage.english) {
    final goal = target == null ? '' : ' with a target of $target reps';
    return 'Write 10 to 15 short, varied encouragement phrases for a gym '
        'trainer to say during a set of "$name"$goal. Rules: English, '
        'positive and neutral, 2 to 8 words each. Do not use digits or number '
        'words. Do not say the movement is correct, safe or perfect. Do not '
        'mention pain, injury, health or technique. No emojis, no markdown, no '
        'quotation marks inside the phrases. Answer with a JSON array of '
        'strings only, for example ["Let\'s go!", "Keep your rhythm."].';
  }
  final goal = target == null ? '' : ' com objetivo de $target repetições';
  return 'Escreve de 10 a 15 frases curtas e variadas de incentivo para um '
      'treinador de ginásio dizer durante uma série de "$name"$goal. Regras: '
      'português europeu (PT-PT), tratamento por "tu", positivas e neutras, '
      'de 2 a 8 palavras cada. Não uses algarismos nem números por extenso. '
      'Não digas que o movimento está correto, seguro ou perfeito. Não '
      'menciones dor, lesões, saúde nem técnica. Sem emojis, sem markdown, '
      'sem aspas dentro das frases. Responde apenas com um array JSON de '
      'strings, por exemplo ["Vamos a isso!", "Mantém o ritmo."].';
}

/// Builds the request for the post-set comment. Plain text answer.
String buildCommentaryPrompt({
  required CoachSetFacts facts,
  required VoiceLanguage language,
}) {
  final name = _promptSafe(facts.exerciseName);
  final observed = facts.observations
      .map(_promptSafe)
      .where((o) => o.isNotEmpty)
      .take(4)
      .toList();
  final target = facts.targetReps;
  if (language == VoiceLanguage.english) {
    return 'Write at most two short sentences for a gym trainer to say at the '
        'end of a set of "$name". Use only these numbers, exactly as written: '
        'full reps ${facts.fullReps}, partial reps ${facts.partialReps}, '
        'duration ${facts.durationSeconds} seconds'
        '${target == null ? '' : ', target ${facts.targetReps}'}. '
        '${observed.isEmpty ? '' : 'Camera observations (not a technique check): ${observed.join('; ')}. '}'
        'Do not say the technique is correct, safe or perfect; do not mention '
        'pain, injury or health. No emojis, no markdown. Answer with the text '
        'only.';
  }
  return 'Escreve no máximo duas frases curtas para um treinador dizer no fim '
      'de uma série de "$name". Usa apenas estes números, exatamente como '
      'estão escritos: repetições completas ${facts.fullReps}, incompletas '
      '${facts.partialReps}, duração ${facts.durationSeconds} segundos'
      '${target == null ? '' : ', objetivo $target'}. '
      '${observed.isEmpty ? '' : 'Observações da câmara (não são avaliação técnica): ${observed.join('; ')}. '}'
      'Português europeu (PT-PT), tratamento por "tu". Não digas que a técnica '
      'está correta, segura ou perfeita; não menciones dor, lesões ou saúde. '
      'Sem emojis, sem markdown. Responde apenas com o texto.';
}

/// Parses the model answer for the phrase bank. Accepts a bare JSON array or
/// one wrapped in text or a code fence. Returns an empty list unless at least
/// [CoachPhraseRules.minBankSize] phrases pass validation.
List<String> parseCoachPhraseBank(
  String raw, {
  required VoiceLanguage language,
}) {
  final array = _extractJsonArray(raw);
  if (array == null) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(array);
  } catch (_) {
    return const [];
  }
  if (decoded is! List) return const [];
  final seen = <String>{};
  final phrases = <String>[];
  for (final item in decoded) {
    if (item is! String) continue;
    final phrase = validateCoachPhrase(item, language: language);
    if (phrase == null) continue;
    if (!seen.add(_dedupeKey(phrase))) continue;
    phrases.add(phrase);
    if (phrases.length == CoachPhraseRules.maxBankSize) break;
  }
  if (phrases.length < CoachPhraseRules.minBankSize) return const [];
  return phrases;
}

/// Returns the phrase trimmed and unquoted, or null when it breaks a rule:
/// length, word count, digits, markdown or emoji, blocked words.
String? validateCoachPhrase(String raw, {required VoiceLanguage language}) {
  final s = _unquote(raw.trim());
  if (s.length < CoachPhraseRules.minLength ||
      s.length > CoachPhraseRules.maxPhraseLength) {
    return null;
  }
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words == 0 || words > CoachPhraseRules.maxWords) return null;
  if (_rejectReason(s, language) != null) return null;
  // Spelled-out numbers ("dez") could state a count, so they are rejected too.
  final numbers = _spelledNumbers(language);
  if (_tokens(s, language).any(numbers.containsKey)) return null;
  return s;
}

/// Returns the commentary when it is at most two sentences, has no blocked
/// words, and every number in it is one of [CoachSetFacts.allowedNumbers].
/// Otherwise null (the caller then speaks nothing extra).
String? validateCoachCommentary(
  String raw, {
  required CoachSetFacts facts,
  required VoiceLanguage language,
}) {
  final s = _unquote(raw.trim());
  if (s.isEmpty || s.length > CoachPhraseRules.maxCommentaryLength) {
    return null;
  }
  if (_rejectReason(s, language, allowDigits: true) != null) return null;
  final sentences = s
      .split(RegExp(r'[.!?]+'))
      .where((p) => p.trim().isNotEmpty)
      .length;
  if (sentences == 0 || sentences > CoachPhraseRules.maxCommentarySentences) {
    return null;
  }
  // Every digit run must be a number we gave the model.
  final allowed = facts.allowedNumbers;
  for (final match in RegExp(r'\p{Nd}+', unicode: true).allMatches(s)) {
    final value = int.tryParse(match.group(0)!);
    if (value == null || !allowed.contains(value)) return null;
  }
  // Number words are checked too, except articles such as "um" and "uma".
  final tokens = _tokens(s, language);
  for (final token in tokens) {
    final value = _spelledNumbers(language)[token];
    if (value != null && !allowed.contains(value)) return null;
  }
  return s;
}

/// Model call with the rules above applied and a hard timeout. Every failure
/// (unavailable model, error, timeout, invalid output) gives the fallback:
/// an empty bank or a null comment.
class CoachLlmPhrases {
  CoachLlmPhrases(
    this._llm, {
    this.bankTimeout = const Duration(seconds: 8),
    this.commentaryTimeout = const Duration(seconds: 6),
  });

  final OnDeviceLlm _llm;
  final Duration bankTimeout;
  final Duration commentaryTimeout;

  /// True only when the system model reports `available`.
  Future<bool> isAvailable() async {
    try {
      return await _llm.status() == LlmStatus.available;
    } catch (_) {
      return false;
    }
  }

  /// Phrase bank for the positioning stage. Empty when unavailable, slow or
  /// invalid.
  Future<List<String>> generatePhraseBank({
    required String exerciseName,
    required int? targetReps,
    required VoiceLanguage language,
  }) async {
    try {
      return await _run(
        () async {
          if (!await isAvailable()) return const <String>[];
          final raw = await _llm.generate(
            buildPhraseBankPrompt(
              exerciseName: exerciseName,
              targetReps: targetReps,
              language: language,
            ),
          );
          return parseCoachPhraseBank(raw, language: language);
        },
        bankTimeout,
        const <String>[],
      );
    } catch (_) {
      return const [];
    }
  }

  /// Post-set comment, or null when unavailable, slow or invalid.
  Future<String?> generateCommentary({
    required CoachSetFacts facts,
    required VoiceLanguage language,
  }) async {
    try {
      return await _run<String?>(
        () async {
          if (!await isAvailable()) return null;
          final raw = await _llm.generate(
            buildCommentaryPrompt(facts: facts, language: language),
          );
          return validateCoachCommentary(raw, facts: facts, language: language);
        },
        commentaryTimeout,
        null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<T> _run<T>(
    Future<T> Function() body,
    Duration limit,
    T fallback,
  ) async {
    try {
      return await body().timeout(limit, onTimeout: () => fallback);
    } catch (_) {
      return fallback;
    }
  }
}

// ---------------------------------------------------------------- helpers

/// Words that must never reach the speaker. Matched against normalised tokens
/// (lower case, no accents): an exact token, or a token that starts with one
/// of the stems.
const _blockedPtTokens = {
  'voce',
  'voces',
  'pra',
  'ta',
  'galera',
  'beleza',
  'dor',
  'dores',
};
const _blockedPtStems = [
  'seguro',
  'segura',
  'seguran',
  'lesa',
  'lesio',
  'perfeit',
  'correto',
  'correta',
  'corretament',
  'medic',
  'tecnic',
  'tecnica',
];
const _blockedEnTokens = <String>{'pain', 'hurt', 'injury'};
const _blockedEnStems = [
  'safe',
  'injur',
  'pain',
  'perfect',
  'correct',
  'doctor',
  'medic',
  'techni',
];

String? _rejectReason(
  String s,
  VoiceLanguage language, {
  bool allowDigits = false,
}) {
  if (RegExp(r'[\r\n\t]').hasMatch(s)) return 'multiline';
  if (!allowDigits && RegExp(r'\p{Nd}', unicode: true).hasMatch(s)) {
    return 'digits';
  }
  if (RegExp(r'[*_#`~<>\[\]{}|\\/"@^=]').hasMatch(s)) return 'markup';
  if (RegExp(
    r'[\p{Extended_Pictographic}\p{Emoji_Presentation}‍️]',
    unicode: true,
  ).hasMatch(s)) {
    return 'emoji';
  }
  final tokens = _tokens(s, language);
  final tokenSet = tokens.toSet();
  final stems = language == VoiceLanguage.portuguese
      ? _blockedPtStems
      : _blockedEnStems;
  final exact = language == VoiceLanguage.portuguese
      ? _blockedPtTokens
      : _blockedEnTokens;
  for (final token in tokens) {
    if (exact.contains(token)) return 'blocked';
    for (final stem in stems) {
      if (token.startsWith(stem)) return 'blocked';
    }
  }
  if (tokenSet.isEmpty) return 'empty';
  return null;
}

/// Lower-case, accent-free word tokens.
List<String> _tokens(String s, VoiceLanguage language) {
  final folded = _fold(s);
  return folded.split(RegExp(r'[^a-z]+')).where((t) => t.isNotEmpty).toList();
}

String _fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final index = from.indexOf(ch);
    buffer.write(index >= 0 ? to[index] : ch);
  }
  return buffer.toString().toLowerCase();
}

Map<String, int> _spelledNumbers(VoiceLanguage language) =>
    language == VoiceLanguage.portuguese ? _ptNumberWords : _enNumberWords;

const _ptNumberWords = <String, int>{
  'dois': 2,
  'duas': 2,
  'tres': 3,
  'quatro': 4,
  'cinco': 5,
  'seis': 6,
  'sete': 7,
  'oito': 8,
  'nove': 9,
  'dez': 10,
  'onze': 11,
  'doze': 12,
  'vinte': 20,
};

const _enNumberWords = <String, int>{
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'twenty': 20,
};

/// Removes one pair of wrapping quotes or stray quote characters at the ends.
String _unquote(String s) {
  var out = s;
  const quotes = '"\'“”«»‘’`';
  while (out.isNotEmpty && quotes.contains(out[0])) {
    out = out.substring(1).trimLeft();
  }
  while (out.isNotEmpty && quotes.contains(out[out.length - 1])) {
    out = out.substring(0, out.length - 1).trimRight();
  }
  return out;
}

String? _extractJsonArray(String raw) {
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start < 0 || end <= start) return null;
  return raw.substring(start, end + 1);
}

String _dedupeKey(String phrase) => _fold(
  phrase,
).replaceAll(RegExp(r'[^a-z ]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Keeps names short and on one line before they go into a prompt.
String _promptSafe(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\r\n\t"]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}
