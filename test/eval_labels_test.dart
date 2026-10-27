import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/eval/scoring.dart';

/// Every `key` in every label file must exist in assets/nutrition/foods.json.
/// Files that are not present on this machine (gitignored datasets) are skipped.
/// Fix a failure with tool/eval/refresh_labels.ps1 (datasets) or by editing eval/labels.json.
void main() {
  final foodKeys = <String>{};
  final foods = File('assets/nutrition/foods.json').readAsStringSync();
  final keyPattern = RegExp(r'"key"\s*:\s*"([^"]+)"');
  foodKeys.addAll(keyPattern.allMatches(foods).map((m) => m.group(1)!));

  const labelFiles = [
    'eval/labels.json',
    'eval/datasets/nutrition5k/labels.json',
    'eval/datasets/nutrition5k_50/labels.json',
    'eval/datasets/nutrition5k_holdout/labels.json',
  ];

  test('foods.json has keys', () {
    expect(foodKeys, isNotEmpty);
  });

  for (final path in labelFiles) {
    test('label keys exist in foods.json: $path', () {
      final file = File(path);
      if (!file.existsSync()) {
        markTestSkipped('$path not present on this machine');
        return;
      }
      final labels = parseLabels(file.readAsStringSync());
      expect(labels, isNotEmpty, reason: '$path has no entries');
      final errors = validateLabelKeys(labels, foodKeys);
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }

  test('holdout and train subsets do not share a photo', () {
    final train = File('eval/datasets/nutrition5k_50/labels.json');
    final holdout = File('eval/datasets/nutrition5k_holdout/labels.json');
    if (!train.existsSync() || !holdout.existsSync()) {
      markTestSkipped('subset label files not present');
      return;
    }
    final trainFiles = {
      for (final l in parseLabels(train.readAsStringSync())) l.file,
    };
    final holdoutFiles = {
      for (final l in parseLabels(holdout.readAsStringSync())) l.file,
    };
    expect(trainFiles.intersection(holdoutFiles), isEmpty);
  });
}
