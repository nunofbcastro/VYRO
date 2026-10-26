/// On-device model support for workout plans. The model never chooses
/// exercises, sets, reps or rest. It may only rephrase the deterministic
/// facts in [GeneratedPlan.notes] as one short summary sentence.
library;

/// Prompt that asks for a short summary of the given facts. The facts are the
/// only content the model may use.
String buildRationalePrompt(List<String> facts, {required bool english}) {
  final language = english ? 'English' : 'Portuguese (Portugal)';
  final list = facts.map((fact) => '- $fact').join('\n');
  return '''
You summarise a training plan for a user. Reply in $language with ONE short sentence (at most 40 words) in plain language.
Use ONLY the facts below. Do not add exercises, numbers, medical advice or claims that the plan is safe or correct.
Facts:
$list''';
}

/// Words that must never appear in a generated summary: safety or technique
/// claims, medical claims, and promises.
const _blockedWords = [
  'seguro',
  'segura',
  'correto',
  'correta',
  'perfeito',
  'safe',
  'correct',
  'perfect',
  'diagnos',
  'tratar',
  'cura',
  'cure',
  'guarantee',
  'garante',
  'garantido',
  'guaranteed',
];

/// Returns the model's sentence when it is usable, otherwise null so the
/// caller shows only the deterministic facts.
///
/// Checks: non-empty, at most 300 characters, one line, no blocked word, and
/// no digit that does not appear in the facts.
String? parseRationale(String raw, List<String> facts) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty || text.length > 300) return null;
  final lower = text.toLowerCase();
  if (_blockedWords.any(lower.contains)) return null;
  final allowedDigits = facts.join(' ').replaceAll(RegExp(r'[^0-9]'), '');
  for (final digit in text.replaceAll(RegExp(r'[^0-9]'), '').split('')) {
    if (!allowedDigits.contains(digit)) return null;
  }
  return text;
}
