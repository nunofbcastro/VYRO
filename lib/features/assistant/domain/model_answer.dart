import '../../../core/ai/on_device_llm.dart';
import '../../nutrition/data/food_database.dart';
import 'meal_math.dart';
import 'meal_proposal.dart';
import 'prose_numbers.dart';

/// An answer from the on-device model, after the app has checked it.
class ComposedAnswer {
  const ComposedAnswer({
    required this.text,
    this.meal,
    this.rejected = false,
    this.footnote,
  });

  /// Text to show. Empty when nothing in the model text survived the check.
  final String text;

  /// The meal card, computed from the database; null when there is no proposal.
  final ResolvedMeal? meal;

  /// The proposal violated the dietary choice and was refused.
  final bool rejected;

  /// One short footnote, only when lines of the model text were removed.
  /// Shown once, outside the message text (see the assistant page).
  final String? footnote;
}

/// Asks the model and composes the answer (see [composeModelAnswer]).
/// Errors from [llm] propagate to the caller.
Future<ComposedAnswer> answerFromModel({
  required OnDeviceLlm llm,
  required String prompt,
  required FoodDatabase db,
  String? diet,
  required bool english,
}) async {
  final raw = await llm.generate(prompt);
  return composeModelAnswer(raw, db, diet: diet, english: english);
}

/// Validates a raw model answer before anything is shown.
///
/// - The `[[MEAL]]` proposal is resolved against the database; its card shows
///   those totals (partial when an item has no values, "a confirmar" when an
///   item has alternatives).
/// - Lines of the prose that carry nutrient numbers not matching the local
///   totals are removed (see [checkProseNumbers]); a note says so.
/// - A proposal that violates the dietary choice is refused.
ComposedAnswer composeModelAnswer(
  String raw,
  FoodDatabase db, {
  String? diet,
  required bool english,
}) {
  final parsed = extractMealProposal(raw);
  final meal = parsed.proposal == null
      ? null
      : resolveMeal(parsed.proposal!, db, diet: diet);
  final prose = stripProtocolText(parsed.text);
  if (meal != null && meal.hasDietConflict) {
    return ComposedAnswer(
      text: english
          ? 'This suggestion did not respect your dietary profile. Please ask for another.'
          : 'Esta sugestão não respeitou a tua opção alimentar. Pede outra sugestão.',
      rejected: true,
    );
  }
  final check = checkProseNumbers(
    prose,
    totals: meal != null && meal.complete ? meal.totals : null,
  );
  return ComposedAnswer(
    text: check.text,
    meal: meal,
    footnote: check.removedLines > 0
        ? (english
              ? 'Some sentences were removed: their numbers did not match the local database.'
              : 'Algumas frases foram retiradas: os números não coincidiam com a base local.')
        : null,
  );
}

/// Removes leftover protocol text from the model reply so it never reaches
/// the screen: an unclosed meal block (and everything after it), stray block
/// markers and JSON lines.
String stripProtocolText(String text) {
  final kept = <String>[];
  for (final line in text.split('\n')) {
    final open = line.indexOf('[[MEAL]]');
    if (open >= 0) {
      final before = line.substring(0, open).trim();
      if (before.isNotEmpty) kept.add(before);
      break;
    }
    final t = line.trim();
    if (t == '[[/MEAL]]' ||
        t.startsWith('{') ||
        t.contains('"items"') ||
        t.contains('"grams"') ||
        t.contains('"meal"')) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n').trim();
}
