import '../../assistant/domain/meal_proposal.dart' show foodTokens;
import '../data/food_database.dart';
import 'food_screening.dart' show normaliseFoodName;

/// Names the photo model may answer in English, mapped to a Portuguese name
/// the food database matches. Keys are normalised (lower case, no accents,
/// words separated by one space). Generic English words ("drink", "meal",
/// "beverage") are not here: they are generic names in food_screening.dart.
const englishFoodNames = <String, String>{
  'egg': 'ovo',
  'eggs': 'ovo',
  'beer': 'cerveja',
  'beers': 'cerveja',
  'cider': 'sidra',
  'water': 'água mineral',
  'sparkling water': 'água com gás',
  'mineral water': 'água mineral',
  'wine': 'vinho',
  'red wine': 'vinho tinto',
  'white wine': 'vinho branco',
  'coffee': 'café',
  'espresso': 'café expresso',
  'steak': 'bife',
  'beef steak': 'bife',
  'fries': 'batatas fritas',
  'french fries': 'batatas fritas',
  'bread': 'pão',
  'toast': 'pão torrado',
  'cheese': 'queijo',
  'rice': 'arroz',
  'pasta': 'massa',
  'spaghetti': 'massa',
  'noodles': 'massa',
  'lasagna': 'lasanha',
  'chicken': 'frango',
  'chicken breast': 'peito de frango',
  'salad': 'salada',
  'green salad': 'salada verde',
  'juice': 'sumo',
  'orange juice': 'sumo de laranja',
  'soda': 'refrigerante',
  'soft drink': 'refrigerante',
  'cola': 'coca-cola',
  'coke': 'coca-cola',
  'lemonade': 'limonada',
  'tea': 'chá',
  'milk': 'leite',
  'butter': 'manteiga',
  'honey': 'mel',
  'sauce': 'molho',
  'ketchup': 'ketchup',
  'mayonnaise': 'maionese',
  'mayo': 'maionese',
  'cream': 'natas',
  'potato': 'batata',
  'potatoes': 'batata',
  'tomato': 'tomate',
  'tomatoes': 'tomate',
  'lettuce': 'alface',
  'onion': 'cebola',
  'carrot': 'cenoura',
  'bean': 'feijão',
  'beans': 'feijão',
  'beef': 'carne de vaca',
  'pork': 'porco',
  // A bare English burger in a photo is the whole sandwich, not the patty.
  // "big mac" has no entry here: the branded row carries it as an alias.
  'hamburger': 'hambúrguer no pão',
  'burger': 'hambúrguer no pão',
  'cheeseburger': 'hambúrguer no pão',
  'patty': 'hambúrguer de vaca',
  'beef patty': 'hambúrguer de vaca',
  'ham': 'fiambre',
  'sausage': 'salsicha',
  'pizza': 'pizza',
  'soup': 'sopa',
  'cake': 'bolo',
  'cookie': 'bolacha',
  'cookies': 'bolacha',
  'yogurt': 'iogurte',
  'yoghurt': 'iogurte',
  'apple': 'maçã',
  'banana': 'banana',
  'orange': 'laranja',
  'strawberry': 'morango',
  'strawberries': 'morango',
  'grape': 'uva',
  'grapes': 'uvas',
  'tuna': 'atum',
  'salmon': 'salmão',
  'shrimp': 'camarão',
  'prawns': 'camarão',
  'avocado': 'abacate',
  'omelette': 'omelete',
  'omelet': 'omelete',
  'croissant': 'croissant',
  'chocolate': 'chocolate',
  'ice cream': 'gelado',
  'pancake': 'panqueca',
};

const _englishArticles = {'a', 'an', 'the'};

/// English name → Portuguese name for a normalised phrase, or null. A leading
/// English article is ignored ("a beer" → cerveja).
String? englishFoodName(String normalised) {
  final key = normalised.trim();
  final direct = englishFoodNames[key];
  if (direct != null) return direct;
  final words = key.split(' ');
  if (words.length > 1 && _englishArticles.contains(words.first)) {
    return englishFoodNames[words.skip(1).join(' ')];
  }
  return null;
}

/// Singular forms of one plural-looking Portuguese word, most likely first.
/// Words of three letters or fewer are never changed.
List<String> _singularOptions(String word) {
  if (word.length <= 3) return const [];
  String stem(int cut) => word.substring(0, word.length - cut);
  if (word.endsWith('aes')) return ['${stem(3)}ao']; // pães → pão
  if (word.endsWith('oes')) return ['${stem(3)}ao']; // limões → limão
  if (word.endsWith('ns')) return ['${stem(2)}m']; // atuns → atum
  if (word.endsWith('is')) return ['${stem(2)}l']; // vegetais → vegetal
  if (word.endsWith('es')) return [stem(1), stem(2)]; // tomates → tomate
  if (word.endsWith('as')) return ['${stem(1)}']; // batatas → batata
  if (word.endsWith('os')) return ['${stem(1)}']; // ovos → ovo
  if (word.endsWith('s')) return [stem(1)]; // morangos → morango
  return const [];
}

/// Singular fallbacks for a normalised name, tried after the name itself:
/// every plural-looking word singularised ("batatas fritas" → "batata frita"),
/// then the last word alone with each alternative ("tomates" → "tomate").
List<String> singularVariants(String normalised) {
  final words = normalised.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final out = <String>[];
  void add(String s) {
    if (s != normalised && s.isNotEmpty && !out.contains(s)) out.add(s);
  }

  add(
    [
      for (final w in words)
        if (_singularOptions(w) case final options when options.isNotEmpty)
          options.first
        else
          w,
    ].join(' '),
  );
  final last = words.last;
  for (final option in _singularOptions(last)) {
    add([...words.take(words.length - 1), option].join(' '));
  }
  return out;
}

/// Names to try against the database, in order: the name as the model wrote
/// it, its normalised form, an English translation, then Portuguese singular
/// fallbacks of both. The first candidate the database matches wins, so an
/// original that matches is never replaced by a guess.
List<String> foodNameCandidates(String raw) {
  final out = <String>[];
  void add(String s) {
    final t = s.trim();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }

  final trimmed = raw.trim();
  add(trimmed);
  final base = normaliseFoodName(trimmed);
  add(base);
  final translated = englishFoodName(base);
  if (translated != null) add(translated);
  final seeds = <String>[
    base,
    if (translated != null) normaliseFoodName(translated),
  ];
  for (final seed in seeds) {
    for (final variant in singularVariants(seed)) {
      add(variant);
      final english = englishFoodName(variant);
      if (english != null) add(english);
    }
  }
  return out;
}

/// English spellings to try for a model name, the name first, then its
/// singular/plural forms ("almond" → "almonds", "berries" → "berry",
/// "peaches" → "peach"). Only the last word changes.
List<String> englishNameVariants(String normalised) {
  final words = normalised.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final last = words.last;
  final options = <String>{last};
  if (last.endsWith('ies') && last.length > 4) {
    options.add('${last.substring(0, last.length - 3)}y');
  } else if (last.endsWith('es') && last.length > 3) {
    options.add(last.substring(0, last.length - 2));
    options.add(last.substring(0, last.length - 1));
  } else if (last.endsWith('s') && last.length > 3) {
    options.add(last.substring(0, last.length - 1));
  } else if (last.length > 2) {
    options.add('${last}s');
    if (RegExp(r'(x|ch|sh)$').hasMatch(last)) options.add('${last}es');
    if (RegExp(r'[^aeiou]y$').hasMatch(last)) {
      options.add('${last.substring(0, last.length - 1)}ies');
    }
  }
  final head = words.take(words.length - 1).toList();
  return [
    for (final o in options) [...head, o].join(' '),
  ];
}

/// The database food whose English name or English alias best matches one of
/// [names] (with their English singular/plural variants). The Portuguese name
/// of a food is not compared here. Null when nothing matches.
FoodRef? matchEnglishFoodName(FoodDatabase db, Iterable<String> names) {
  final queries = <Set<String>>[];
  for (final name in names) {
    for (final variant in englishNameVariants(normaliseFoodName(name))) {
      final tokens = foodTokens(variant);
      if (tokens.isNotEmpty && !queries.any((q) => _sameTokens(q, tokens))) {
        queries.add(tokens);
      }
    }
  }
  if (queries.isEmpty) return null;
  FoodRef? best;
  var bestScore = 0.0;
  for (final food in db.foods) {
    for (final phrase in [food.nameEn, ...food.aliases]) {
      final tokens = foodTokens(phrase);
      if (tokens.isEmpty) continue;
      for (final query in queries) {
        final shared = query.intersection(tokens).length;
        if (shared == 0) continue;
        // Every word of the shorter phrase must be present.
        final smaller = query.length < tokens.length
            ? query.length
            : tokens.length;
        if (shared < smaller) continue;
        final score = shared / (query.length + tokens.length - shared);
        if (score > bestScore) {
          bestScore = score;
          best = food;
        }
      }
    }
  }
  return best;
}

bool _sameTokens(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
