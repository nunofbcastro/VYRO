import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';

DayNote note(int day, [String text = 'mesmo texto']) =>
    DayNote(day: day, pt: text, en: 'same text');

void main() {
  group('groupDayNotes', () {
    test('consecutive identical days become one "Dias 1–3" line', () {
      final grouped = groupDayNotes([note(1), note(2), note(3)]);
      expect(grouped, hasLength(1));
      expect(grouped.single.pt, 'Dias 1–3: mesmo texto');
      expect(grouped.single.en, 'Days 1–3: same text');
    });

    test('non-consecutive identical days list every day', () {
      final grouped = groupDayNotes([note(1), note(3), note(5)]);
      expect(grouped, hasLength(1));
      expect(grouped.single.pt, 'Dias 1, 3 e 5: mesmo texto');
      expect(grouped.single.en, 'Days 1, 3 and 5: same text');
    });

    test('two non-consecutive days use "e" / "and" without a comma', () {
      final grouped = groupDayNotes([note(1), note(3)]);
      expect(grouped.single.pt, 'Dias 1 e 3: mesmo texto');
      expect(grouped.single.en, 'Days 1 and 3: same text');
    });

    test('a single day keeps "Dia 2" / "Day 2"', () {
      final grouped = groupDayNotes([note(2)]);
      expect(grouped.single.pt, 'Dia 2: mesmo texto');
      expect(grouped.single.en, 'Day 2: same text');
    });

    test('different texts stay on separate lines', () {
      final grouped = groupDayNotes([
        note(1, 'texto A'),
        note(2, 'texto B'),
        note(3, 'texto A'),
        note(4, 'texto C'),
      ]);
      expect(grouped.map((n) => n.pt), [
        'Dias 1 e 3: texto A',
        'Dia 2: texto B',
        'Dia 4: texto C',
      ]);
    });

    test('all different texts give one line per day, in day order', () {
      final grouped = groupDayNotes([
        note(1, 'um'),
        note(2, 'dois'),
        note(3, 'tres'),
      ]);
      expect(grouped.map((n) => n.pt), [
        'Dia 1: um',
        'Dia 2: dois',
        'Dia 3: tres',
      ]);
      expect(grouped.map((n) => n.en), [
        'Day 1: same text',
        'Day 2: same text',
        'Day 3: same text',
      ]);
    });

    test('the same text is compared in both languages', () {
      final grouped = groupDayNotes([
        const DayNote(day: 1, pt: 'igual', en: 'same'),
        const DayNote(day: 2, pt: 'igual', en: 'different'),
      ]);
      expect(grouped, hasLength(2));
    });

    test('unsorted input is labelled in day order', () {
      final grouped = groupDayNotes([note(3), note(1), note(2)]);
      expect(grouped.single.pt, 'Dias 1–3: mesmo texto');
    });

    test('empty input gives no notes', () {
      expect(groupDayNotes(const []), isEmpty);
    });
  });
}
