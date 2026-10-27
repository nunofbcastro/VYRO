import '../../../core/ai/on_device_llm.dart';
import '../../nutrition/data/food_database.dart';
import 'meal_math.dart';
import 'meal_proposal.dart';

// Meal resolution lives in meal_math.dart; re-exported for existing callers.
export 'meal_math.dart' show ResolvedMeal, foodFitsDiet, resolveMeal;

class LocalAssistantAnswer {
  const LocalAssistantAnswer(this.text, {this.proposal});
  final String text;
  final MealProposal? proposal;
}

/// Answers factual requests without a model. No action writes to the diary.
LocalAssistantAnswer? answerLocally(
  String question,
  AssistantContext c,
  FoodDatabase db, {
  bool english = false,
  String meal = 'dinner',
  DateTime? now,
}) {
  final q = foodTokens(question).join(' ');
  String text(String pt, String en) => english ? en : pt;
  final clock = now ?? DateTime.now();
  final plain = foldText(question);
  if (_timePhrases.contains(plain))
    return LocalAssistantAnswer(localTimeAnswer(clock, english));
  if (_datePhrases.contains(plain))
    return LocalAssistantAnswer(localDateAnswer(clock, english));
  if (_greetingPhrases.contains(plain))
    return LocalAssistantAnswer(
      '${text('Olá!', 'Hello!')} ${localAssistantHelp(english)}',
    );
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
  if (isOutOfScope(question))
    return LocalAssistantAnswer(localScopeReply(english));
  return null;
}

String localAssistantHelp(bool english) => english
    ? 'I can check today’s remaining macros, your next workout, yesterday’s dinner and your last analysed set, or suggest a meal from the local database.'
    : 'Posso consultar os macros que faltam hoje, o próximo treino, o jantar de ontem e a última série analisada, ou sugerir uma refeição da base local.';

/// Lower-case, accent-free text with punctuation removed, for phrase matching.
String foldText(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var out = input.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _timePhrases = {
  'que horas',
  'que horas sao',
  'que horas e',
  'que horas sao agora',
  'que horas e agora',
  'que hora e',
  'que hora e agora',
  'hora certa',
  'what time is it',
  'what time is it now',
  'whats the time',
  'what s the time',
  'current time',
};

const _datePhrases = {
  'que dia e hoje',
  'que dia da semana e hoje',
  'que dia da semana e',
  'qual e o dia de hoje',
  'qual e a data de hoje',
  'que data e hoje',
  'dia de hoje',
  'data de hoje',
  'what day is it',
  'what day is it today',
  'what day is today',
  'what is the date today',
  'whats the date today',
  'what s the date today',
  'what date is it',
  'what date is it today',
  'todays date',
};

const _greetingPhrases = {
  'ola',
  'ola tudo bem',
  'oi',
  'oi tudo bem',
  'bom dia',
  'boa tarde',
  'boa noite',
  'ola bom dia',
  'ola boa tarde',
  'ola boa noite',
  'hello',
  'hi',
  'hey',
  'good morning',
  'good afternoon',
  'good evening',
};

/// Words that show the question belongs to nutrition, training or app data.
/// Prefixes, so "treinador" and "comida" match too.
final _domainWords = RegExp(
  r'\b(comer|comi|comida|refei|almo|jant|pequeno almo|lanche|proteina|calori|'
  r'kcal|macro|hidrat|carboid|gordur|fome|dieta|aliment|nutri|treina|treino|'
  r'exercic|serie|repeti|plano|peso|meta|diario|receita|sugir|sugest|sugere|'
  r'vegan|vegetar|agua|suplement|musc|cardio|corrida|passo|jejum|ingred|'
  r'grama|rotina|arroz|ovo|carne|peixe|pao|massa|sono|falta)',
);

/// Clear requests outside the assistant's scope. A question is only out of
/// scope when it matches one of these cues AND has no domain word, so
/// borderline questions still reach the model.
final _outOfScopeCues = RegExp(
  r'\b(capital de|capital do|capital da|presidente|primeiro ministro|noticia|'
  r'noticias|futebol|golo|benfica|sporting|filme|serie de tv|musica|cancao|'
  r'poema|poesia|piada|anedota|codigo|programar|programacao|python|javascript|'
  r'bug|matematica|calcula|raiz quadrada|equacao|quem foi|quem e|onde fica|'
  r'traduz|traducao|bitcoin|bolsa|eleicoes|politica|previsao|clima|'
  r'meteorologia|weather|capital of|president|news|football|movie|song|poem|'
  r'joke|translate|math)\b',
);

/// True when a question is clearly outside nutrition, training and app data.
bool isOutOfScope(String question) {
  final plain = foldText(question);
  if (plain.isEmpty) return false;
  if (_domainWords.hasMatch(plain)) return false;
  return _outOfScopeCues.hasMatch(plain);
}

/// Time in PT-PT (device clock), e.g. "São 14h32." or "É 1h05.".
String localTimeAnswer(DateTime now, bool english) {
  final hh = now.hour.toString();
  final mm = now.minute.toString().padLeft(2, '0');
  if (english) {
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    return 'It is $h12:$mm $ampm.';
  }
  return '${now.hour == 1 ? 'É' : 'São'} ${hh}h$mm.';
}

const _weekdaysPt = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _weekdaysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthsPt = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Date in PT-PT, e.g. "Hoje é segunda-feira, 26 de outubro de 2026."
String localDateAnswer(DateTime now, bool english) {
  final wd = now.weekday - 1;
  final m = now.month - 1;
  if (english) {
    return 'Today is ${_weekdaysEn[wd]}, ${_monthsEn[m]} ${now.day}, ${now.year}.';
  }
  return 'Hoje é ${_weekdaysPt[wd]}, ${now.day} de ${_monthsPt[m]} de ${now.year}.';
}

/// Short reply for questions outside the assistant's scope. It does not call
/// the model.
String localScopeReply(bool english) => english
    ? 'I can only help with nutrition, training and your data in this app. For example: "What do I have left today?", "What is my next workout?" or "Suggest a dinner with protein."'
    : 'Só posso ajudar com nutrição, treino e os teus dados desta app. Por exemplo: "O que me falta hoje?", "Qual é o próximo treino?" ou "Sugere um jantar com proteína".';
