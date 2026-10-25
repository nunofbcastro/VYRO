import 'food_vision.dart';

/// Rules that decide which items of the phone model's answer are real foods
/// in the photo. Pure Dart: no model, no database, no I/O.
///
/// The same small model writes the draft and confirms it, so these rules do
/// not trust its confirmation alone: non-food objects are removed, generic
/// names are flagged for the user, and drinks without container evidence and
/// items without a location go to suggestions ("Outras hipóteses"), which
/// never count in the totals.

/// Lower case, accents removed, punctuation turned into single spaces.
String normaliseFoodName(String raw) {
  const accented = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const plain = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final ch in raw.toLowerCase().split('')) {
    final i = accented.indexOf(ch);
    buffer.write(i < 0 ? ch : plain[i]);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Words that carry no meaning in a short food name.
const _stopWords = {
  'de',
  'do',
  'da',
  'dos',
  'das',
  'um',
  'uma',
  'uns',
  'umas',
  'o',
  'a',
  'os',
  'as',
  'e',
  'em',
  'no',
  'na',
  'com',
  'of',
  'the',
  'an',
  'and',
  'with',
  'on',
  'in',
};

List<String> _tokens(String raw) => [
  for (final t in normaliseFoodName(raw).split(' '))
    if (t.isNotEmpty && !_stopWords.contains(t)) t,
];

/// Objects on a table. A name is a non-food when every word left after
/// dropping articles is one of these: "toalha" and "guardanapo de papel" are
/// dropped, "copo" alone too, while "copo de água" stays.
const _nonFoodWords = {
  'toalha',
  'toalhete',
  'toalhetes',
  'guardanapo',
  'guardanapos',
  'prato',
  'copo',
  'copos',
  'chavena',
  'chavenas',
  'garrafa',
  'garrafas',
  'lata',
  'latas',
  'talher',
  'talheres',
  'garfo',
  'faca',
  'colher',
  'mesa',
  'papel',
  'lenco',
  'lencos',
  'caixa',
  'menu',
  'ementa',
  'recibo',
  'talao',
  'saco',
  'embalagem',
  'tabuleiro',
  'frigideira',
  'panela',
  'tacho',
  'tabua',
  'base',
  'individual',
  'napkin',
  'napkins',
  'towel',
  'towels',
  'plate',
  'plates',
  'glass',
  'glasses',
  'cup',
  'cups',
  'bottle',
  'bottles',
  'can',
  'cans',
  'fork',
  'knife',
  'spoon',
  'table',
  'paper',
  'box',
  'receipt',
  'bag',
  'pan',
  'tray',
};

/// True when the name is only non-food words ("toalha", "guardanapo de papel").
bool isNonFoodName(String name) {
  final tokens = _tokens(name);
  return tokens.isNotEmpty && tokens.every(_nonFoodWords.contains);
}

/// Words that show a drink is held in a container.
const _containerWords = {
  'copo',
  'copos',
  'chavena',
  'chavenas',
  'caneca',
  'canecas',
  'garrafa',
  'garrafas',
  'lata',
  'latas',
  'taca',
  'tacas',
  'jarro',
  'jarros',
  'cup',
  'cups',
  'glass',
  'glasses',
  'mug',
  'mugs',
  'bottle',
  'bottles',
  'can',
  'cans',
};

/// True when a "where" text names a container ("cup top-left", "copo").
bool mentionsContainer(String? where) {
  if (where == null) return false;
  return normaliseFoodName(where).split(' ').any(_containerWords.contains);
}

const _drinkWords = {
  'agua',
  'sumo',
  'cerveja',
  'vinho',
  'cafe',
  'expresso',
  'espresso',
  'bica',
  'galao',
  'cha',
  'leite',
  'refrigerante',
  'cocktail',
  'whisky',
  'gin',
  'vodka',
  'licor',
  'beirao',
  'sangria',
  'cidra',
  'bebida',
  'champanhe',
  'espumante',
  'limonada',
  'juice',
  'beer',
  'wine',
  'coffee',
  'tea',
  'soda',
  'milk',
  'water',
  'cola',
  'latte',
  'cappuccino',
  'drink',
};

/// Drink by database category or by the name's words.
bool isDrinkItem(DetectedFood food) {
  if (food.food?.category == 'bebidas') return true;
  return _tokens(food.label).any(_drinkWords.contains);
}

/// Generic names: the photo shows a kind of food, not a specific one.
enum GenericKind { drink, sandwich, sauce, meat, fish, fruit, dessert, food }

const _genericNames = <String, GenericKind>{
  'bebida': GenericKind.drink,
  'bebidas': GenericKind.drink,
  'drink': GenericKind.drink,
  'drinks': GenericKind.drink,
  'sanduiche': GenericKind.sandwich,
  'sanduiches': GenericKind.sandwich,
  'sandes': GenericKind.sandwich,
  'sandwich': GenericKind.sandwich,
  'molho': GenericKind.sauce,
  'molhos': GenericKind.sauce,
  'sauce': GenericKind.sauce,
  'carne': GenericKind.meat,
  'meat': GenericKind.meat,
  'peixe': GenericKind.fish,
  'fish': GenericKind.fish,
  'fruta': GenericKind.fruit,
  'fruit': GenericKind.fruit,
  'sobremesa': GenericKind.dessert,
  'dessert': GenericKind.dessert,
  'comida': GenericKind.food,
  'refeicao': GenericKind.food,
  'refeicoes': GenericKind.food,
  'food': GenericKind.food,
  'meal': GenericKind.food,
};

/// The generic kind of a name ("uma bebida" → drink), or null if specific.
GenericKind? genericKindOf(String name) {
  final tokens = _tokens(name);
  if (tokens.isEmpty) return null;
  return _genericNames[tokens.join(' ')];
}

/// Removes non-food names; the removed labels are returned for diagnostics.
({List<DetectedFood> kept, List<String> dropped}) dropNonFood(
  List<DetectedFood> draft,
) {
  final kept = <DetectedFood>[];
  final dropped = <String>[];
  for (final item in draft) {
    if (isNonFoodName(item.label)) {
      dropped.add(item.label);
    } else {
      kept.add(item);
    }
  }
  return (kept: kept, dropped: dropped);
}

/// What happened to one item of the first answer, for "Detalhes da análise".
enum ItemAction { kept, dropped, suggestion }

/// One diagnostic line: `cerveja → kept (verify=true, drink, where "top right")`.
String decisionLine(String label, ItemAction action, String reason) =>
    '$label → ${action.name} ($reason)';

/// Result of the verification step for the non-food-filtered items.
class DraftDecision {
  const DraftDecision({required this.foods, required this.decisions});

  /// Items that stay in the review (and in totals once matched). Includes
  /// items whose verdict was omitted or rejected-all: they are uncertain.
  final List<DetectedFood> foods;

  /// One entry per item that was checked, with the reason.
  final List<ItemDecision> decisions;
}

/// One checked item and its outcome.
class ItemDecision {
  const ItemDecision({
    required this.item,
    required this.action,
    required this.reason,
  });

  final DetectedFood item;
  final ItemAction action;
  final String reason;
}

/// Applies the verification verdicts. Only an explicit `false` removes an
/// item, and only while at least one item survives: if verification rejects
/// every item, all of them are kept as uncertain ("verify rejected all"),
/// because a model that rejects its whole draft is more likely wrong than
/// right. The `where` text and drink words are evidence written into the
/// reason, never a gate: a small model often omits `where`.
///
/// [verdicts] is null when verification was unparsed or failed: every item
/// stays. Otherwise there is one entry per item: `true` or `null` keep it
/// (null is uncertain: the review already shows "Hipótese a confirmar"),
/// `false` drops it.
DraftDecision decideDraft(List<DetectedFood> kept, {List<bool?>? verdicts}) {
  bool? verdictAt(int i) =>
      verdicts == null ? null : (i < verdicts.length ? verdicts[i] : null);
  var rejected = 0;
  for (var i = 0; i < kept.length; i++) {
    if (verdictAt(i) == false) rejected++;
  }
  final rejectedAll = kept.isNotEmpty && rejected == kept.length;
  final foods = <DetectedFood>[];
  final decisions = <ItemDecision>[];
  for (var i = 0; i < kept.length; i++) {
    final item = kept[i];
    final verdict = verdictAt(i);
    if (verdict == false && !rejectedAll) {
      decisions.add(
        ItemDecision(
          item: item,
          action: ItemAction.dropped,
          reason: 'verify=false',
        ),
      );
      continue;
    }
    final where = item.where;
    final evidence = [
      if (rejectedAll)
        'verify rejected all — kept as uncertain'
      else if (verdicts == null)
        'verify unparsed'
      else if (verdict == null)
        'verify omitted, uncertain'
      else
        'verify=true',
      if (item.needsChoice) 'generic name, needs choice',
      if (where == null || where.isEmpty) 'no where' else 'where "$where"',
      if (isDrinkItem(item))
        mentionsContainer(where)
            ? 'drink, container in where'
            : 'drink, no container in where',
    ];
    foods.add(item);
    decisions.add(
      ItemDecision(
        item: item,
        action: ItemAction.kept,
        reason: evidence.join(', '),
      ),
    );
  }
  return DraftDecision(foods: foods, decisions: decisions);
}
