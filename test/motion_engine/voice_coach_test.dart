import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/feedback_engine/feedback_engine.dart';
import 'package:vyro/features/motion_engine/feedback_engine/voice_coach.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';

Duration sec(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

VoiceObservation rep(
  double at,
  int full, {
  int partial = 0,
  RepEventType type = RepEventType.full,
}) => VoiceObservation(
  at: sec(at),
  ready: true,
  repEvent: type,
  fullReps: full,
  partialReps: partial,
);

// Form and visibility cues do not depend on the start cue, so `ready` stays
// false here and the start cue does not interfere with ordering assertions.
VoiceObservation feedback(double at, String key, FeedbackLevel level) =>
    VoiceObservation(
      at: sec(at),
      feedback: FeedbackMessage(key, level, sec(at)),
    );

SetSummary summary({int full = 0, int partial = 0, Duration? hold}) =>
    SetSummary(
      patternId: 'squat',
      duration: sec(30),
      fullReps: full,
      partialReps: partial,
      events: const [],
      meanConfidence: 0.9,
      observedRatio: 0.95,
      holdTime: hold ?? Duration.zero,
      status: AnalysisStatus.withinCriteria,
    );

String? spokenAt(VoiceCoach coach, double seconds) =>
    coach.next(sec(seconds))?.text;

void main() {
  group('rep counting', () {
    test('full reps are counted aloud in PT-PT, in order', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(1, 1));
      expect(spokenAt(coach, 1), 'Um');
      coach.observe(rep(2, 2));
      expect(spokenAt(coach, 2), 'Dois');
      coach.observe(rep(3, 3));
      expect(spokenAt(coach, 3), 'Três');
    });

    test('full reps are counted aloud in English', () {
      final coach = VoiceCoach(language: VoiceLanguage.english)..startSet();
      coach.observe(rep(1, 1));
      expect(spokenAt(coach, 1), 'One');
      coach.observe(rep(2, 2));
      expect(spokenAt(coach, 2), 'Two');
    });

    test('counts above twenty are spoken as digits', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(1, 21));
      expect(spokenAt(coach, 1), '21');
    });

    test('a partial rep is not counted aloud as a full rep', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      final queued = coach.observe(
        rep(1, 0, partial: 1, type: RepEventType.partial),
      );
      expect(queued.map((p) => p.text), ['Essa foi incompleta.']);
      expect(spokenAt(coach, 1), 'Essa foi incompleta.');
      expect(coach.next(sec(1)), isNull);
    });

    test('an abandoned rep says nothing', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      // Not framed: the start cue is not part of this check.
      expect(
        coach.observe(
          VoiceObservation(at: sec(1), repEvent: RepEventType.abandoned),
        ),
        isEmpty,
      );
    });
  });

  group('start cue', () {
    test('is spoken once per set, when the body is framed', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      expect(
        coach.observe(VoiceObservation(at: sec(0))),
        isEmpty,
        reason: 'not framed yet',
      );
      final first = coach.observe(VoiceObservation(at: sec(1), ready: true));
      expect(first.single.text, 'Estou a ver-te. Quando quiseres, começa.');
      expect(
        coach.observe(VoiceObservation(at: sec(10), ready: true)),
        isEmpty,
      );
      coach.startSet();
      expect(
        coach.observe(VoiceObservation(at: sec(20), ready: true)),
        hasLength(1),
        reason: 'a new set repeats the start cue',
      );
    });
  });

  group('milestones', () {
    test('with a target: two more, last one, halfway, target reached', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)
        ..startSet(targetReps: 10);
      expect(coach.observe(rep(1, 5)).map((p) => p.text), [
        'Cinco',
        'Metade feita!',
      ]);
      expect(coach.observe(rep(2, 8)).map((p) => p.text), [
        'Oito',
        'Mais duas!',
      ]);
      expect(coach.observe(rep(3, 9)).map((p) => p.text), ['Nove', 'Última!']);
      expect(coach.observe(rep(4, 10)).map((p) => p.text), [
        'Dez',
        'Objetivo atingido!',
      ]);
    });

    test('without a target: every five reps', () {
      final coach = VoiceCoach(language: VoiceLanguage.english)..startSet();
      expect(coach.observe(rep(1, 4)).map((p) => p.text), ['Four']);
      expect(coach.observe(rep(2, 5)).map((p) => p.text), [
        'Five',
        'That\'s 5. Nice!',
      ]);
    });
  });

  group('form cues', () {
    test('use the feedback engine message through the text resolver', () {
      final coach = VoiceCoach(
        language: VoiceLanguage.portuguese,
        cueText: (key) => 'texto de $key',
      )..startSet();
      final queued = coach.observe(
        feedback(1, 'mfTrunkUpright', FeedbackLevel.warning),
      );
      expect(queued.single.text, 'texto de mfTrunkUpright');
    });

    test('are throttled: at most one every 4 s', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      expect(
        coach.observe(feedback(0, 'mfTrunkUpright', FeedbackLevel.warning)),
        hasLength(1),
      );
      expect(
        coach.observe(feedback(1, 'mfNoSwing', FeedbackLevel.warning)),
        isEmpty,
        reason: 'another cue within 4 s',
      );
      expect(
        coach.observe(feedback(4, 'mfNoSwing', FeedbackLevel.warning)),
        hasLength(1),
      );
    });

    test('the same cue is not repeated within 10 s', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(feedback(0, 'mfTrunkUpright', FeedbackLevel.warning));
      coach.observe(feedback(4, 'mfNoSwing', FeedbackLevel.warning));
      expect(
        coach.observe(feedback(8, 'mfTrunkUpright', FeedbackLevel.warning)),
        isEmpty,
      );
      expect(
        coach.observe(feedback(12, 'mfNoSwing', FeedbackLevel.warning)),
        isEmpty,
        reason: 'the same key within 10 s of its last cue at 4 s',
      );
      expect(
        coach.observe(feedback(14, 'mfTrunkUpright', FeedbackLevel.warning)),
        hasLength(1),
      );
    });

    test('success messages and partial-rep info are not spoken as cues', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      expect(
        coach.observe(feedback(0, 'mfRepDone', FeedbackLevel.success)),
        isEmpty,
      );
      expect(
        coach.observe(feedback(5, 'mfPartialRep', FeedbackLevel.info)),
        isEmpty,
      );
    });

    test('lost visibility gives the visibility phrase', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      final queued = coach.observe(
        feedback(0, 'mfAdjustCamera', FeedbackLevel.setup),
      );
      expect(queued.single.text, 'Não te vejo bem, afasta-te um pouco.');
    });
  });

  group('priority', () {
    test('a rep count is spoken before a queued form cue', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(feedback(0, 'mfTrunkUpright', FeedbackLevel.warning));
      coach.observe(rep(0.5, 1));
      expect(spokenAt(coach, 0.5), 'Um');
      expect(spokenAt(coach, 0.5), 'mfTrunkUpright');
      expect(coach.next(sec(0.5)), isNull);
    });

    test('encouragement is spoken after the count, before cues', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)
        ..startSet(targetReps: 10);
      coach.observe(feedback(0, 'mfNoSwing', FeedbackLevel.warning));
      coach.observe(rep(0.2, 8));
      expect(spokenAt(coach, 0.2), 'Oito');
      expect(spokenAt(coach, 0.2), 'Mais duas!');
      expect(spokenAt(coach, 0.2), 'mfNoSwing');
    });
  });

  group('stale phrases and queue', () {
    test('a phrase older than 2 s is dropped, not spoken late', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(0, 1));
      expect(coach.next(sec(2.5)), isNull);
      expect(coach.pendingCount, 0);
    });

    test('a phrase within 2 s is still spoken', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(0, 1));
      expect(spokenAt(coach, 1.9), 'Um');
    });

    test('the set summary is never dropped as stale', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(VoiceObservation(at: sec(0), summary: summary(full: 2)));
      expect(spokenAt(coach, 60), 'Boa! 2 repetições, sem incompletas.');
    });

    test('the queue is bounded and drops the lowest priority first', () {
      final coach = VoiceCoach(
        language: VoiceLanguage.portuguese,
        maxPending: 2,
      )..startSet();
      coach.observe(feedback(0, 'mfAdjustCamera', FeedbackLevel.setup));
      coach.observe(rep(0.1, 5));
      expect(coach.pendingCount, 2);
      expect(spokenAt(coach, 0.1), 'Cinco');
      expect(spokenAt(coach, 0.1), 'Já são 5. Boa!');
      expect(coach.next(sec(0.1)), isNull);
    });

    test('clear() drops everything queued', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(0, 1));
      coach.observe(rep(0, 2));
      expect(coach.pendingCount, greaterThan(0));
      coach.clear();
      expect(coach.next(sec(0)), isNull);
    });
  });

  group('disabled coach', () {
    test('produces no phrases', () {
      final coach = VoiceCoach(
        language: VoiceLanguage.portuguese,
        enabled: false,
      )..startSet();
      expect(coach.observe(rep(0, 1)), isEmpty);
      expect(coach.observe(VoiceObservation(at: sec(0), ready: true)), isEmpty);
      expect(
        coach.observe(VoiceObservation(at: sec(0), summary: summary(full: 3))),
        isEmpty,
      );
      expect(coach.next(sec(0)), isNull);
    });

    test('turning it off drops the queue; turning it on resumes', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(0, 1));
      expect(coach.pendingCount, 1);
      coach.setEnabled(false);
      expect(coach.pendingCount, 0);
      expect(coach.next(sec(0)), isNull);
      coach.setEnabled(true);
      expect(coach.observe(rep(1, 2)), hasLength(1));
    });
  });

  group('set summary', () {
    test('PT-PT with partial reps', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(
        VoiceObservation(at: sec(0), summary: summary(full: 10, partial: 2)),
      );
      expect(spokenAt(coach, 0), 'Boa! 10 repetições, 2 incompletas.');
    });

    test('singular forms', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(
        VoiceObservation(at: sec(0), summary: summary(full: 1, partial: 1)),
      );
      expect(spokenAt(coach, 0), 'Boa! 1 repetição, 1 incompleta.');
    });

    test('English', () {
      final coach = VoiceCoach(language: VoiceLanguage.english)..startSet();
      coach.observe(
        VoiceObservation(at: sec(0), summary: summary(full: 10, partial: 2)),
      );
      expect(spokenAt(coach, 0), 'Good! 10 reps, 2 partial reps.');
    });

    test('no reps counted', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(VoiceObservation(at: sec(0), summary: summary()));
      expect(spokenAt(coach, 0), 'Série terminada. Nenhuma repetição contada.');
    });

    test('hold patterns speak the time in position', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(
        VoiceObservation(
          at: sec(0),
          summary: summary(hold: sec(30)),
        ),
      );
      expect(spokenAt(coach, 0), 'Boa! 30 segundos em posição.');
    });

    test('replaces phrases still queued', () {
      final coach = VoiceCoach(language: VoiceLanguage.portuguese)..startSet();
      coach.observe(rep(0, 1));
      coach.observe(VoiceObservation(at: sec(0), summary: summary(full: 1)));
      expect(coach.pendingCount, 1);
      expect(spokenAt(coach, 0), 'Boa! 1 repetição, sem incompletas.');
    });
  });
}
