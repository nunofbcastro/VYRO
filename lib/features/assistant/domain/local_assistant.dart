import '../../../core/ai/on_device_llm.dart';
import '../../nutrition/data/food_database.dart';
import 'meal_proposal.dart';

class LocalAssistantAnswer {
  const LocalAssistantAnswer(this.text, {this.proposal});
  final String text;
  final MealProposal? proposal;
}

/// Conservative candidate filter; mixed dishes require recipe-level knowledge.
bool foodFitsDiet(FoodRef food, String? diet) {
  if (diet != 'vegan' && diet != 'vegetarian') return true;
  if ({'carne', 'peixe', 'salgados', 'pratos'}.contains(food.category))
    return false;
  if (diet == 'vegetarian') return true;
  if ({'ovos', 'laticínios', 'sobremesas'}.contains(food.category))
    return false;
  if ({
    'butter_salted',
    'honey',
    'coffee_with_milk',
    'croissant',
    'pao_de_queijo',
    'tapioca_butter',
    'farofa',
  }.contains(food.key))
    return false;
  return true;
}

class ResolvedMeal {
  ResolvedMeal(this.proposal, this.foods);
  final MealProposal proposal;
  final List<FoodRef?> foods;
  bool get complete => foods.every((f) => f != null);
  double total(double Function(FoodRef) nutrient) {
    var value = 0.0;
    for (var i = 0; i < foods.length; i++) {
      if (foods[i] != null)
        value += nutrient(foods[i]!) * proposal.items[i].grams / 100;
    }
    return value;
  }

  String label(bool english) =>
      '${complete ? (english ? "Database values" : "Valores da base") : (english ? "Partial values — resolve foods" : "Valores parciais — resolve os alimentos")}: ${total((f) => f.kcal).round()} kcal · P ${total((f) => f.protein).round()} g · H ${total((f) => f.carbs).round()} g · G ${total((f) => f.fat).round()} g';
}

ResolvedMeal resolveMeal(
  MealProposal proposal,
  FoodDatabase db, {
  String? diet,
}) => ResolvedMeal(proposal, [
  for (final item in proposal.items)
    switch (db.match(item.name)) {
      final FoodRef f when foodFitsDiet(f, diet) => f,
      _ => null,
    },
]);

/// Answers factual requests without a model. No action writes to the diary.
LocalAssistantAnswer? answerLocally(
  String question,
  AssistantContext c,
  FoodDatabase db, {
  bool english = false,
  String meal = 'dinner',
}) {
  final q = foodTokens(question).join(' ');
  String text(String pt, String en) => english ? en : pt;
  if (RegExp(
    r'\b(falta|faltam|resta|restam|saldo|remaining|left|consumi|consumido|consumed|macros)\b',
  ).hasMatch(q)) {
    if (c.kcalGoal == null || c.kcalToday == null)
      return LocalAssistantAnswer(
        text(
          'Ainda não tens uma meta definida. Podes defini-la no perfil.',
          'You have no target yet. Set one in your profile.',
        ),
      );
    int left(int? goal, int? value) =>
        ((goal ?? 0) - (value ?? 0)).clamp(0, 100000);
    final values =
        '${left(c.kcalGoal, c.kcalToday)} kcal · P ${left(c.proteinGoal, c.proteinToday)} g · H ${left(c.carbsGoal, c.carbsToday)} g · G ${left(c.fatGoal, c.fatToday)} g';
    return LocalAssistantAnswer(
      '${text("Falta para as metas de hoje", "Remaining towards today’s targets")}: $values.\n${c.partialNutrition ? text("Os totais são parciais: há nutrientes desconhecidos no diário.", "Totals are partial: some diary nutrients are unknown.") : text("Calculado a partir do diário local.", "Calculated from your local diary.")}',
    );
  }
  if (RegExp(r'\b(ontem|yesterday)\b').hasMatch(q))
    return LocalAssistantAnswer(
      c.previousDinner.isEmpty
          ? text(
              'Não tens jantar registado ontem.',
              'You have no dinner logged yesterday.',
            )
          : '${text("Jantar de ontem, registado por ti", "Yesterday’s dinner, logged by you")}:\n${c.previousDinner.join("\n")}',
    );
  if (RegExp(r'(ultima|ultimo|last) (serie|set|analise|analysis)').hasMatch(q))
    return LocalAssistantAnswer(
      c.lastSet ??
          text(
            'Ainda não tens uma análise de movimento guardada.',
            'You have no saved movement analysis yet.',
          ),
    );
  if (RegExp(
    r'(proximo|next|hoje|today).*(treino|workout)|(treino|workout).*(proximo|next|hoje|today)',
  ).hasMatch(q))
    return LocalAssistantAnswer(
      c.nextWorkout == null
          ? text(
              'Não há próximo treino agendado.',
              'No next workout is scheduled.',
            )
          : '${text("Próximo treino registado", "Next scheduled workout")}: ${c.nextWorkout}${c.nextWorkoutDay == null ? "" : " (${c.nextWorkoutDay})"}\n${c.nextExercises.join("\n")}',
    );
  if (RegExp(
    r'\b(sugere|sugerir|suggest|janto|jantar|almoco|lunch|dinner|proteina|protein)\b',
  ).hasMatch(q)) {
    final keys = [
      c.dietaryChoice == 'vegan' || c.dietaryChoice == 'vegetarian'
          ? 'lentils_cooked'
          : 'chicken_breast_roasted',
      'rice_white_cooked',
      'broccoli_cooked',
    ];
    final foods = [
      for (final k in keys)
        if (db.byKey(k) != null && foodFitsDiet(db.byKey(k)!, c.dietaryChoice))
          db.byKey(k)!,
    ];
    if (foods.isEmpty) return null;
    final proposal = MealProposal(
      meal: meal,
      items: [
        for (final food in foods)
          ProposedItem(name: food.name(english), grams: food.portionG),
      ],
    );
    final resolved = resolveMeal(proposal, db, diet: c.dietaryChoice);
    return LocalAssistantAnswer(
      '${text("Sugestão local a rever", "Local suggestion to review")}\n${resolved.label(english)}\n${text("Confirma os alimentos, as porções e as tuas restrições antes de registar. Não inclui adaptações automáticas às preferências em texto livre.", "Confirm the foods, portions and your restrictions before logging. Free-text preferences are not automatically applied.")}',
      proposal: proposal,
    );
  }
  return null;
}

String localAssistantHelp(bool english) => english
    ? 'I can check today’s remaining macros, your next workout, yesterday’s dinner and your last analysed set, or suggest a meal from the local database.'
    : 'Posso consultar os macros que faltam hoje, o próximo treino, o jantar de ontem e a última série analisada, ou sugerir uma refeição da base local.';
