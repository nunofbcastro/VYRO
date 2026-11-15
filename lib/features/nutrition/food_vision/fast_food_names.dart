/// Menu names for fast-food phrases the photo model writes loosely
/// ("mac chicken", "bigmac", "mcdonald's chicken sandwich"). Generic names
/// ("burger", "chicken sandwich") stay null so they keep the generic row
/// and the branded sandwiches stay suggestions.

const _gluedFastFood = {
  'bigmac': ['big', 'mac'],
  'bigtasty': ['big', 'tasty'],
  'mcchicken': ['mc', 'chicken'],
  'mchicken': ['mc', 'chicken'],
  'mccrispy': ['mc', 'crispy'],
  'mcnugget': ['mc', 'nugget'],
  'mcnuggets': ['mc', 'nuggets'],
  'mcroyal': ['mc', 'royal'],
};

const _accented = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _plain = 'aaaaaeeeeiiiiooooouuuucn';

String _words(String raw) {
  final lower = raw.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = _accented.indexOf(ch);
    buffer.write(i >= 0 ? _plain[i] : ch);
  }
  return buffer.toString();
}

List<String> _unfold(String word) => _gluedFastFood[word] ?? [word];

/// Canonical menu phrase, or null when [raw] is not a branded fast-food name.
String? fastFoodCanonical(String raw) {
  final words = <String>[
    for (final part in _words(raw).split(RegExp(r'[^a-z0-9]+')))
      if (part.isNotEmpty) ..._unfold(part),
  ];
  if (words.isEmpty) return null;
  if (words.contains('mac') &&
      words.contains('chicken') &&
      !words.contains('big')) {
    for (var i = 0; i < words.length; i++) {
      if (words[i] == 'mac') words[i] = 'mc';
    }
  }
  bool has(String w) => words.contains(w);
  // "molho big mac" is the sauce, not the sandwich.
  if (has('molho') || has('molhos') || has('sauce')) return null;
  final brand = has('mc') || has('mcdonalds') || has('mcdonald');

  if (has('hot') &&
      has('honey') &&
      (has('crispy') || has('chicken') || has('sandwich') || brand)) {
    return 'mccrispy hot honey';
  }
  if (has('cheddar') && has('bacon') && (has('crispy') || brand)) {
    return 'mccrispy cheddar bacon';
  }
  if (brand && has('crispy')) return 'mccrispy';
  if (has('cbo')) return 'cbo';
  if (has('zinger')) {
    const specific = {
      'extreme',
      'kentucky',
      'boxmaster',
      'coronel',
      'cheddar',
      'fondue',
      'bbq',
      'wrap',
      'double',
      'original',
      'veggie',
    };
    if (!words.any(specific.contains)) {
      if (has('tower')) return 'tower zinger';
      return 'zinger';
    }
    if (has('tower')) return 'tower zinger';
  }
  if (has('big') && has('tasty') && has('double')) return 'big tasty double';
  if (has('big') && has('tasty')) return 'big tasty';
  if (has('big') && has('mac')) return 'big mac';
  if (has('double') && has('mc') && has('royal')) return 'double mcroyal bacon';
  if (has('mc') && has('royal')) return 'mcroyal';
  if (has('double') &&
      (has('cheeseburger') ||
          (has('cheese') && (has('burger') || has('hamburger'))))) {
    return 'double cheeseburger';
  }
  if (has('mc') && (has('nugget') || has('nuggets'))) {
    return 'chicken mcnuggets';
  }
  if (has('mc') && has('chicken')) return 'mcchicken';
  if (brand &&
      has('chicken') &&
      (has('sandwich') || has('burger') || has('sandes') || has('sanduiche')) &&
      !has('crispy')) {
    return 'mcchicken';
  }
  if (has('whopper') && !has('junior')) {
    if (has('cheese') || has('queijo')) return 'whopper with cheese';
    return 'whopper';
  }
  return null;
}
