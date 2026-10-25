import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/feedback_engine/voice_coach.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';

Duration sec(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

VoiceCoach coach({bool enabled = true}) => VoiceCoach(
  language: VoiceLanguage.portuguese,
  enabled: enabled,
  cueText: (key) => 'T:$key',
)..startSet();

void main() {
  group('framing prompts before a set', () {
    test('the framing key is spoken through the text callback', () {
      final c = coach();
      c.observe(VoiceObservation(at: sec(0), framingKey: 'frTooClose'));
      expect(c.next(sec(0))?.text, 'T:frTooClose');
    });

    test('framing prompts are at least 5 s apart', () {
      final c = coach();
      c.observe(VoiceObservation(at: sec(0), framingKey: 'frOffCentre'));
      expect(c.next(sec(0))?.text, 'T:frOffCentre');

      c.observe(VoiceObservation(at: sec(2), framingKey: 'frOffCentre'));
      expect(c.next(sec(2)), isNull, reason: 'throttled at 2 s');

      c.observe(VoiceObservation(at: sec(4.9), framingKey: 'frTooFar'));
      expect(c.next(sec(4.9)), isNull, reason: 'throttled at 4.9 s');

      c.observe(VoiceObservation(at: sec(5), framingKey: 'frTooFar'));
      expect(c.next(sec(5))?.text, 'T:frTooFar');
    });

    test('a disabled coach queues no framing prompt', () {
      final c = coach(enabled: false);
      expect(
        c.observe(VoiceObservation(at: sec(0), framingKey: 'frTooClose')),
        isEmpty,
      );
      expect(c.next(sec(0)), isNull);
    });

    test('a framing prompt does not delay the first rep count', () {
      final c = coach();
      c.observe(VoiceObservation(at: sec(0), framingKey: 'frTooClose'));
      c.observe(
        VoiceObservation(
          at: sec(0.1),
          ready: true,
          repEvent: RepEventType.full,
          fullReps: 1,
        ),
      );
      expect(c.next(sec(0.1))?.text, 'Um');
      expect(c.next(sec(0.1))?.text, 'T:frTooClose');
    });
  });

  group('start cue after positioning', () {
    test(
      'the start cue is spoken once aligned and not repeated in the set',
      () {
        final c = coach();
        final queued = c.observe(VoiceObservation(at: sec(0), ready: true));
        expect(queued, hasLength(1));
        expect(c.next(sec(0))?.text, contains('Estou a ver-te'));

        // The set starts: the target changes but the start cue is not replayed.
        c.setTarget(10);
        expect(c.target, 10);
        expect(c.observe(VoiceObservation(at: sec(1), ready: true)), isEmpty);
      },
    );

    test('setTarget keeps the start cue flag, startSet resets it', () {
      final c = coach();
      c.observe(VoiceObservation(at: sec(0), ready: true));
      c.next(sec(0));
      c.setTarget(5);
      expect(c.observe(VoiceObservation(at: sec(10), ready: true)), isEmpty);

      c.startSet(targetReps: 5);
      expect(
        c.observe(VoiceObservation(at: sec(20), ready: true)),
        hasLength(1),
      );
    });

    test('a framing prompt does not block the start cue', () {
      final c = coach();
      c.observe(VoiceObservation(at: sec(0), framingKey: 'frNotVisible'));
      expect(c.next(sec(0))?.text, 'T:frNotVisible');
      // Framing has its own 5 s limit; the start cue uses the cue limit.
      c.observe(VoiceObservation(at: sec(1), ready: true));
      expect(c.next(sec(1))?.text, contains('Estou a ver-te'));
    });
  });
}
