import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/feedback_engine/voice_coach.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';

Duration _sec(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

VoiceObservation _rep(double at, int full) => VoiceObservation(
  at: _sec(at),
  ready: true,
  repEvent: RepEventType.full,
  fullReps: full,
);

void main() {
  group('target reps reach the coach', () {
    test('a target gives English milestone phrases', () {
      final coach = VoiceCoach(language: VoiceLanguage.english)
        ..startSet(targetReps: 8);
      expect(coach.target, 8);
      expect(coach.observe(_rep(1, 4)).map((p) => p.text), [
        'Four',
        'Halfway there!',
      ]);
      expect(coach.observe(_rep(2, 6)).map((p) => p.text), [
        'Six',
        'Two more!',
      ]);
      expect(coach.observe(_rep(3, 7)).map((p) => p.text), [
        'Seven',
        'Last one!',
      ]);
      expect(coach.observe(_rep(4, 8)).map((p) => p.text), [
        'Eight',
        'Target reached!',
      ]);
    });

    test('without a target there is no milestone at the halfway count', () {
      final coach = VoiceCoach(language: VoiceLanguage.english)..startSet();
      expect(coach.target, isNull);
      expect(coach.observe(_rep(1, 4)).map((p) => p.text), ['Four']);
    });

    test('a new set without a target clears the previous target', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)
        ..startSet(targetReps: 10);
      coach.startSet();
      expect(coach.target, isNull);
    });
  });
}
