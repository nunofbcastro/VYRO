/// Validates imported local preferences before a database transaction replaces data.
void validateLocalData(String key, Map<String, dynamic> data) {
  bool number(Object? v, {bool positive = false}) =>
      v is num && v.isFinite && (positive ? v > 0 : v >= 0);
  if (key == 'assistant_memory_v1') {
    if (data.length > 20 ||
        data.entries.any(
          (e) =>
              e.key.length > 80 ||
              e.value is! String ||
              (e.value as String).length > 240,
        ))
      throw const FormatException('Invalid memories');
  } else if (key == 'quality_metrics_v1') {
    if (data.length > 20 || data.values.any((v) => !number(v)))
      throw const FormatException('Invalid metrics');
  } else if (key == 'food_corrections_v1') {
    if (data['enabled'] != null && data['enabled'] is! bool)
      throw const FormatException('Invalid learning setting');
    final rows = data['rows'];
    if (rows != null) {
      if (rows is! Map || rows.length > 200)
        throw const FormatException('Invalid corrections');
      for (final e in rows.entries) {
        if (e.key is! String ||
            (e.key as String).length > 240 ||
            e.value is! Map)
          throw const FormatException('Invalid correction');
        final counts = e.value as Map;
        if (counts.length > 200 ||
            counts.entries.any(
              (v) => v.key is! String || !number(v.value, positive: true),
            ))
          throw const FormatException('Invalid correction counts');
      }
    }
  } else if (key == 'recipes_v1') {
    if (data.length > 100) throw const FormatException('Recipe limit');
    for (final e in data.entries) {
      final r = e.value;
      if (r is! Map ||
          r['id'] != e.key ||
          e.key.length > 80 ||
          r['name'] is! String ||
          (r['name'] as String).trim().isEmpty ||
          (r['name'] as String).length > 80 ||
          !number(r['yieldGrams'], positive: true) ||
          (r['yieldGrams'] as num) > 100000)
        throw const FormatException('Invalid recipe');
      final items = r['ingredients'];
      if (items is! List || items.isEmpty || items.length > 100)
        throw const FormatException('Invalid ingredients');
      for (final i in items) {
        if (i is! Map ||
            i['key'] is! String ||
            i['name'] is! String ||
            (i['name'] as String).length > 120 ||
            !number(i['grams'], positive: true) ||
            (i['grams'] as num) > 100000 ||
            ['kcal', 'protein', 'carbs', 'fat'].any((k) => !number(i[k])))
          throw const FormatException('Invalid ingredient');
      }
    }
  }
}
