import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/progress/domain/body_weight.dart';

void main() {
  group('parseBodyWeight', () {
    test('accepts pt-PT decimal comma and dot', () {
      expect(parseBodyWeight('75,5'), 75.5);
      expect(parseBodyWeight('75.5'), 75.5);
      expect(parseBodyWeight(' 75 '), 75);
      expect(parseBodyWeight('75'), 75);
    });

    test('accepts the range limits', () {
      expect(parseBodyWeight('20'), 20);
      expect(parseBodyWeight('20,0'), 20);
      expect(parseBodyWeight('400'), 400);
    });

    test('rejects values outside 20-400 kg', () {
      expect(parseBodyWeight('19,9'), isNull);
      expect(parseBodyWeight('400,1'), isNull);
      expect(parseBodyWeight('0'), isNull);
      expect(parseBodyWeight('1000'), isNull);
    });

    test('rejects more than one decimal place or malformed text', () {
      expect(parseBodyWeight('75,55'), isNull);
      expect(parseBodyWeight('1,2,3'), isNull);
      expect(parseBodyWeight('1.2.3'), isNull);
      expect(parseBodyWeight('abc'), isNull);
      expect(parseBodyWeight(''), isNull);
      expect(parseBodyWeight('-70'), isNull);
    });
  });

  test('formats the input with a locale-specific decimal separator', () {
    expect(formatBodyWeightInput(75.5, english: false), '75,5');
    expect(formatBodyWeightInput(75.5, english: true), '75.5');
    expect(formatBodyWeight(80, english: false), '80,0 kg');
    expect(formatBodyDate(DateTime(2026, 3, 7)), '07/03/2026');
  });

  test('date picker starts five years back from today', () {
    expect(
      bodyWeightFirstDay(DateTime(2026, 10, 26, 15)),
      DateTime(2021, 10, 26),
    );
  });

  group('bodyMeasuredAt', () {
    final now = DateTime(2026, 10, 26, 9, 30, 15);

    test('today uses the current time', () {
      expect(bodyMeasuredAt(day: DateTime(2026, 10, 26), now: now), now);
    });

    test('a past day uses noon so it stays on that day', () {
      expect(
        bodyMeasuredAt(day: DateTime(2026, 10, 25), now: now),
        DateTime(2026, 10, 25, 12),
      );
    });

    test('an unchanged day keeps the original time of the entry', () {
      final original = DateTime(2026, 10, 25, 7, 5);
      expect(
        bodyMeasuredAt(
          day: DateTime(2026, 10, 25),
          now: now,
          original: original,
        ),
        original,
      );
    });
  });
}
