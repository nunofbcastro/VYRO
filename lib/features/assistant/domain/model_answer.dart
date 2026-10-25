import '../../../core/ai/on_device_llm.dart';
import '../../nutrition/data/food_database.dart';
import 'meal_math.dart';
import 'meal_proposal.dart';
import 'prose_numbers.dart';

/// An answer from the on-device model, after the app has checked it.
class ComposedAnswer {
  const ComposedAnswer({required this.text, this.meal, this.rejected = false});

  /// Text to show. Empty when nothing in the model text survived the check.
  final String text;

  /// The meal card, computed from the database; null when there is no proposal.
  final ResolvedMeal? meal;

  /// The proposal violated the dietary choice and was refused.
  final bool rejected;
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
  if (meal != null && meal.hasDietConflict) {
    return ComposedAnswer(
      text: english
          ? 'This suggestion did not respect your dietary profile. Please ask for another.'
          : 'Esta sugestão não respeitou a tua opção alimentar. Pede outra sugestão.',
      rejected: true,
    );
  }
  final check = checkProseNumbers(
    parsed.text,
    totals: meal != null && meal.complete ? meal.totals : null,
  );
  final notes = [
    if (meal != null)
      english
          ? 'Values calculated by VYRO from the local database (see the meal card).'
          : 'Valores calculados pela VYRO a partir da base local (ver o cartão da refeição).',
    if (check.removedLines > 0)
      english
          ? 'Sentences with nutrient numbers were removed from the model text because they do not match the local database.'
          : 'Frases com números nutricionais foram removidas do texto do modelo, porque não coincidem com a base local.',
  ];
  final parts = [
    if (check.text.isNotEmpty) check.text,
    for (final note in notes) '*$note*',
  ];
  return ComposedAnswer(text: parts.join('\n\n'), meal: meal);
}
