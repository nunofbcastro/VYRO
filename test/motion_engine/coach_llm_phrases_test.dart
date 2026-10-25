import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/feedback_engine/coach_llm_phrases.dart';
import 'package:vyro/features/motion_engine/feedback_engine/voice_coach.dart';
import 'package:vyro/features/motion_engine/repetition_counter/rep_counter_engine.dart';

/// Fake on-device model. [answer] runs for each generate call.
class FakeLlm implements OnDeviceLlm {
  FakeLlm({
    this.llmStatus = LlmStatus.available,
    this.answer,
    this.statusError = false,
  });

  LlmStatus llmStatus;
  final bool statusError;
  final Future<String> Function(String prompt)? answer;
  final prompts = <String>[];

  @override
  Future<LlmStatus> status() async {
    if (statusError) throw const LlmException('status');
    return llmStatus;
  }

  @override
  Future<LlmStatus> download() async => llmStatus;

  @override
  Future<String> generate(String prompt) {
    prompts.add(prompt);
    final handler = answer;
    if (handler == null) return Future.value('[]');
    return handler(prompt);
  }
}

const _pt = VoiceLanguage.portuguese;
const _en = VoiceLanguage.english;

const _facts = CoachSetFacts(
  exerciseName: 'Agachamento',
  fullReps: 8,
  partialReps: 2,
  durationSeconds: 42,
  targetReps: 10,
);

const _goodBank = [
  'Vamos a isso!',
  'Mantém o ritmo.',
  'Respira e continua.',
  'Estás no bom caminho.',
  'Boa energia nessa série.',
  'Sente o movimento.',
];

String _jsonOf(List<String> items) =>
    '[${items.map((s) => '"$s"').join(', ')}]';

Duration sec(double s) => Duration(milliseconds: (s * 1000).round());

/// Every phrase the coach would speak at [now], in order.
List<String> drain(VoiceCoach coach, Duration now) {
  final out = <String>[];
  while (true) {
    final phrase = coach.next(now);
    if (phrase == null) return out;
    out.add(phrase.text);
  }
}

SetSummary _summary({required int full, required int partial}) => SetSummary(
  patternId: 'squat',
  duration: sec(30),
  fullReps: full,
  partialReps: partial,
  events: const [],
  meanConfidence: 0.9,
  observedRatio: 0.9,
  holdTime: Duration.zero,
  status: AnalysisStatus.waiting,
);

void main() {
  group('validateCoachPhrase', () {
    test('accepts a short PT-PT phrase and trims it', () {
      expect(
        validateCoachPhrase('  Vamos a isso!  ', language: _pt),
        'Vamos a isso!',
      );
    });

    test('removes wrapping quotes', () {
      expect(
        validateCoachPhrase('"Mantém o ritmo."', language: _pt),
        'Mantém o ritmo.',
      );
    });

    test('length limits: 60 characters pass, 61 fail, one character fails', () {
      final sixty = 'a' * 60;
      expect(validateCoachPhrase(sixty, language: _en), sixty);
      expect(validateCoachPhrase('a' * 61, language: _en), isNull);
      expect(validateCoachPhrase('a', language: _en), isNull);
    });

    test('word limit: eight words pass, nine fail', () {
      const eight = 'vamos ao ritmo sempre com calma e força';
      const nine = '$eight agora';
      expect(validateCoachPhrase(eight, language: _pt), eight);
      expect(validateCoachPhrase(nine, language: _pt), isNull);
    });

    test('digits are rejected', () {
      expect(validateCoachPhrase('Mais 1 rep!', language: _pt), isNull);
      expect(validateCoachPhrase('Força 2', language: _en), isNull);
    });

    test('spelled-out counts are rejected', () {
      expect(validateCoachPhrase('Faltam dez!', language: _pt), isNull);
      expect(validateCoachPhrase('Two more!', language: _en), isNull);
    });

    test('markdown, emoji and multi-line text are rejected', () {
      expect(validateCoachPhrase('**Força** agora', language: _pt), isNull);
      expect(validateCoachPhrase('Força 💪', language: _pt), isNull);
      expect(validateCoachPhrase('Boa\nsérie', language: _pt), isNull);
    });

    test('blocked safety, pain and correctness words are rejected (PT)', () {
      for (final bad in [
        'Estás seguro?',
        'Cuidado com a lesão',
        'Sem dor',
        'Perfeito!',
        'Está perfeitamente feito',
        'Isso está correto',
        'Pergunta ao médico',
        'Boa técnica',
      ]) {
        expect(validateCoachPhrase(bad, language: _pt), isNull, reason: bad);
      }
    });

    test('Brazilian forms are rejected (PT)', () {
      for (final bad in [
        'Você consegue!',
        'Vamos pra frente',
        'Bora, galera',
      ]) {
        expect(validateCoachPhrase(bad, language: _pt), isNull, reason: bad);
      }
    });

    test('blocked words are rejected in English', () {
      for (final bad in [
        'Safe reps',
        'No pain',
        'Perfect form',
        'You are correct',
      ]) {
        expect(validateCoachPhrase(bad, language: _en), isNull, reason: bad);
      }
      expect(
        validateCoachPhrase('Keep your rhythm', language: _en),
        'Keep your rhythm',
      );
    });
  });

  group('parseCoachPhraseBank', () {
    test('accepts a bare JSON array', () {
      expect(
        parseCoachPhraseBank(_jsonOf(_goodBank), language: _pt),
        _goodBank,
      );
    });

    test('accepts an array inside a code fence or with prose around it', () {
      final bank = parseCoachPhraseBank(
        'Aqui está:\n```json\n${_jsonOf(_goodBank)}\n```',
        language: _pt,
      );
      expect(bank, _goodBank);
    });

    test('invalid JSON gives an empty bank', () {
      expect(
        parseCoachPhraseBank('["Vamos a isso!", ', language: _pt),
        isEmpty,
      );
      expect(parseCoachPhraseBank('sem array nenhum', language: _pt), isEmpty);
    });

    test('a JSON object instead of an array gives an empty bank', () {
      expect(
        parseCoachPhraseBank('{"frases": ["Vamos!"]}', language: _pt),
        isEmpty,
      );
    });

    test('non-string items are skipped', () {
      final bank = parseCoachPhraseBank(
        '[1, null, ${_goodBank.map((s) => '"$s"').join(', ')}, {"a": 1}]',
        language: _pt,
      );
      expect(bank, _goodBank);
    });

    test('fewer than five valid phrases give an empty bank', () {
      expect(
        parseCoachPhraseBank(
          '["Vamos a isso!", "Mantém o ritmo.", "Pára 2 segundos", "Dor não"]',
          language: _pt,
        ),
        isEmpty,
      );
    });

    test('invalid items are dropped and the valid ones kept', () {
      final bank = parseCoachPhraseBank(
        _jsonOf([..._goodBank, 'Mais 1 rep', 'Perfeito!', '**Bom**']),
        language: _pt,
      );
      expect(bank, _goodBank);
    });

    test('duplicates are removed, ignoring case and punctuation', () {
      final bank = parseCoachPhraseBank(
        _jsonOf([
          'Vamos a isso!',
          'vamos a isso',
          'VAMOS A ISSO!!',
          'Mantém o ritmo.',
          'Respira e continua.',
          'Boa energia nessa série.',
          'Sente o movimento.',
        ]),
        language: _pt,
      );
      expect(bank, [
        'Vamos a isso!',
        'Mantém o ritmo.',
        'Respira e continua.',
        'Boa energia nessa série.',
        'Sente o movimento.',
      ]);
    });

    test('at most fifteen phrases are kept', () {
      final letters = [
        for (var i = 0; i < 25; i++)
          'Frase ${String.fromCharCode(0x61 + i)} força',
      ];
      final bank = parseCoachPhraseBank(_jsonOf(letters), language: _pt);
      expect(bank, hasLength(CoachPhraseRules.maxBankSize));
    });
  });

  group('validateCoachCommentary', () {
    test('accepts a short comment that uses only given numbers', () {
      expect(
        validateCoachCommentary(
          'Boa! Oito repetições completas e 2 incompletas.',
          facts: _facts,
          language: _pt,
        ),
        'Boa! Oito repetições completas e 2 incompletas.',
      );
    });

    test('a wrong digit is rejected', () {
      expect(
        validateCoachCommentary(
          'Boa! Fizeste 9 repetições.',
          facts: _facts,
          language: _pt,
        ),
        isNull,
      );
    });

    test('a wrong spelled-out number is rejected', () {
      expect(
        validateCoachCommentary(
          'Fizeste sete repetições.',
          facts: _facts,
          language: _pt,
        ),
        isNull,
      );
    });

    test('a given spelled-out number is accepted (target = 10)', () {
      expect(
        validateCoachCommentary(
          'Chegaste às dez repetições.',
          facts: _facts,
          language: _pt,
        ),
        isNotNull,
      );
    });

    test('duration in seconds is an allowed number', () {
      expect(
        validateCoachCommentary(
          'Durou 42 segundos.',
          facts: _facts,
          language: _pt,
        ),
        isNotNull,
      );
    });

    test('more than two sentences are rejected', () {
      expect(
        validateCoachCommentary(
          'Boa. Bom ritmo. Continua assim.',
          facts: _facts,
          language: _pt,
        ),
        isNull,
      );
    });

    test('blocked and markup content is rejected', () {
      expect(
        validateCoachCommentary(
          'A técnica está perfeita.',
          facts: _facts,
          language: _pt,
        ),
        isNull,
      );
      expect(
        validateCoachCommentary('**Boa** série.', facts: _facts, language: _pt),
        isNull,
      );
      expect(
        validateCoachCommentary('   ', facts: _facts, language: _pt),
        isNull,
      );
    });

    test('over 200 characters is rejected', () {
      expect(
        validateCoachCommentary('a' * 201, facts: _facts, language: _pt),
        isNull,
      );
    });

    test('English numbers are checked too', () {
      expect(
        validateCoachCommentary(
          'Nice, eight reps and three partial.',
          facts: _facts,
          language: _en,
        ),
        isNull,
      );
    });
  });

  group('prompts', () {
    test('phrase bank prompt asks for a JSON array in PT-PT with the name', () {
      final prompt = buildPhraseBankPrompt(
        exerciseName: 'Agachamento',
        targetReps: 10,
        language: _pt,
      );
      expect(prompt, contains('Agachamento'));
      expect(prompt, contains('array JSON'));
      expect(prompt, contains('PT-PT'));
      expect(prompt, contains('objetivo de 10'));
    });

    test('phrase bank prompt in English asks for a JSON array', () {
      final prompt = buildPhraseBankPrompt(
        exerciseName: 'Squat\n"x"',
        targetReps: null,
        language: _en,
      );
      expect(prompt, contains('JSON array'));
      // Newlines and quotes in the name are removed before the prompt.
      expect(prompt, isNot(contains('\n')));
      expect(prompt, contains('Squat'));
    });

    test('commentary prompt lists the exact numbers and observations', () {
      final prompt = buildCommentaryPrompt(
        facts: const CoachSetFacts(
          exerciseName: 'Prancha',
          fullReps: 3,
          partialReps: 1,
          durationSeconds: 30,
          observations: ['Tronco pouco vertical'],
        ),
        language: _pt,
      );
      expect(prompt, contains('repetições completas 3'));
      expect(prompt, contains('incompletas 1'));
      expect(prompt, contains('duração 30 segundos'));
      expect(prompt, contains('Tronco pouco vertical'));
      expect(prompt, contains('não são avaliação técnica'));
    });
  });

  group('CoachLlmPhrases with a fake model', () {
    test('unavailable model: no generation call and fallbacks', () async {
      final llm = FakeLlm(llmStatus: LlmStatus.unavailable);
      final service = CoachLlmPhrases(llm);
      expect(
        await service.generatePhraseBank(
          exerciseName: 'Agachamento',
          targetReps: 10,
          language: _pt,
        ),
        isEmpty,
      );
      expect(
        await service.generateCommentary(facts: _facts, language: _pt),
        isNull,
      );
      expect(llm.prompts, isEmpty);
    });

    test('downloadable (not yet ready) counts as unavailable', () async {
      final llm = FakeLlm(
        llmStatus: LlmStatus.downloadable,
        answer: (_) async => _jsonOf(_goodBank),
      );
      expect(
        await CoachLlmPhrases(llm).generatePhraseBank(
          exerciseName: 'x',
          targetReps: null,
          language: _pt,
        ),
        isEmpty,
      );
      expect(llm.prompts, isEmpty);
    });

    test('status error gives the fallback', () async {
      final llm = FakeLlm(statusError: true);
      expect(
        await CoachLlmPhrases(llm).generatePhraseBank(
          exerciseName: 'x',
          targetReps: null,
          language: _pt,
        ),
        isEmpty,
      );
    });

    test('valid JSON from the model gives the bank', () async {
      final llm = FakeLlm(answer: (_) async => _jsonOf(_goodBank));
      final bank = await CoachLlmPhrases(llm).generatePhraseBank(
        exerciseName: 'Agachamento',
        targetReps: 10,
        language: _pt,
      );
      expect(bank, _goodBank);
      expect(llm.prompts.single, contains('Agachamento'));
    });

    test('invalid JSON gives an empty bank', () async {
      final llm = FakeLlm(answer: (_) async => 'Aqui tens: vamos!');
      expect(
        await CoachLlmPhrases(llm).generatePhraseBank(
          exerciseName: 'x',
          targetReps: null,
          language: _pt,
        ),
        isEmpty,
      );
    });

    test('a model error gives the fallback for both calls', () async {
      final llm = FakeLlm(
        answer: (_) async => throw const LlmException('error'),
      );
      expect(
        await CoachLlmPhrases(llm).generatePhraseBank(
          exerciseName: 'x',
          targetReps: null,
          language: _pt,
        ),
        isEmpty,
      );
      expect(
        await CoachLlmPhrases(
          llm,
        ).generateCommentary(facts: _facts, language: _pt),
        isNull,
      );
    });

    test('a slow bank times out and gives the fallback', () async {
      final never = Completer<String>();
      final llm = FakeLlm(answer: (_) => never.future);
      final service = CoachLlmPhrases(
        llm,
        bankTimeout: const Duration(milliseconds: 30),
      );
      expect(
        await service.generatePhraseBank(
          exerciseName: 'x',
          targetReps: null,
          language: _pt,
        ),
        isEmpty,
      );
    });

    test('a slow commentary times out and gives null', () async {
      final never = Completer<String>();
      final llm = FakeLlm(answer: (_) => never.future);
      final service = CoachLlmPhrases(
        llm,
        commentaryTimeout: const Duration(milliseconds: 30),
      );
      expect(
        await service.generateCommentary(facts: _facts, language: _pt),
        isNull,
      );
    });

    test('a commentary with a wrong number is dropped', () async {
      final llm = FakeLlm(answer: (_) async => 'Fizeste 12 repetições.');
      expect(
        await CoachLlmPhrases(
          llm,
        ).generateCommentary(facts: _facts, language: _pt),
        isNull,
      );
    });

    test('a valid commentary is returned', () async {
      final llm = FakeLlm(
        answer: (_) async => 'Boa! Oito repetições, 2 incompletas.',
      );
      expect(
        await CoachLlmPhrases(
          llm,
        ).generateCommentary(facts: _facts, language: _pt),
        'Boa! Oito repetições, 2 incompletas.',
      );
    });
  });

  group('VoiceCoach with generated phrases', () {
    VoiceObservation full(double at, int count) => VoiceObservation(
      at: sec(at),
      ready: true,
      repEvent: RepEventType.full,
      fullReps: count,
    );

    test('without a bank the milestone is the fixed template', () {
      final coach = VoiceCoach(language: _pt)..startSet();
      coach.observe(full(1, 5));
      expect(
        drain(coach, sec(1.1)),
        containsAllInOrder(['Cinco', 'Já são 5. Boa!']),
      );
    });

    test(
      'with a bank the number stays fixed and a generated phrase follows',
      () {
        final coach = VoiceCoach(language: _pt)..startSet();
        coach.setEncouragementBank(_goodBank);
        coach.observe(full(1, 5));
        expect(
          drain(coach, sec(1.1)),
          containsAllInOrder(['Cinco', 'Já são 5. ${_goodBank.first}']),
        );
      },
    );

    test('count-critical phrases stay fixed even with a bank', () {
      final coach = VoiceCoach(language: _pt)..startSet(targetReps: 10);
      coach.setEncouragementBank(_goodBank);
      coach.observe(full(1, 8));
      expect(drain(coach, sec(1.1)), contains('Mais duas!'));
      coach.observe(full(2, 9));
      expect(drain(coach, sec(2.1)), contains('Última!'));
      coach.observe(full(3, 10));
      expect(drain(coach, sec(3.1)), contains('Objetivo atingido!'));
    });

    test('halfway uses a generated phrase when the bank exists', () {
      final coach = VoiceCoach(language: _pt)..startSet(targetReps: 10);
      coach.setEncouragementBank(['Vamos a isso!']);
      coach.observe(full(1, 5));
      final spoken = drain(coach, sec(1.1));
      expect(spoken, contains('Vamos a isso!'));
      expect(spoken, isNot(contains('Metade feita!')));
    });

    test('an empty bank restores the fixed halfway phrase', () {
      final coach = VoiceCoach(language: _pt)..startSet(targetReps: 10);
      coach.setEncouragementBank(const []);
      coach.observe(full(1, 5));
      expect(drain(coach, sec(1.1)), contains('Metade feita!'));
    });

    test('commentary is queued after the summary and is never stale', () {
      final coach = VoiceCoach(language: _pt);
      coach.observe(
        VoiceObservation(at: sec(0), summary: _summary(full: 8, partial: 2)),
      );
      final added = coach.addCommentary('Boa série, oito.', sec(1));
      expect(added, hasLength(1));
      expect(coach.next(sec(1))?.text, startsWith('Boa!'));
      // Well past the usual two-second staleness window.
      expect(coach.next(sec(30))?.text, 'Boa série, oito.');
    });

    test(
      'commentary is ignored when the coach is off or the text is empty',
      () {
        final off = VoiceCoach(language: _pt, enabled: false);
        expect(off.addCommentary('Boa.', sec(0)), isEmpty);
        final on = VoiceCoach(language: _pt);
        expect(on.addCommentary('  ', sec(0)), isEmpty);
      },
    );
  });
}
