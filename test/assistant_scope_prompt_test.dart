import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';

void main() {
  const context = AssistantContext(kcalGoal: 2400, kcalToday: 1200);

  test(
    'the Portuguese prompt no longer forces a questionnaire or full-day plan',
    () {
      final pt = buildAssistantPrompt(
        question: 'Que horas são?',
        context: context,
      );
      expect(pt, isNot(contains('o que tem em casa')));
      expect(pt, isNot(contains('faz UMA pergunta curta primeiro')));
      expect(pt, contains('Responde só ao que foi perguntado'));
      expect(pt, contains('Não faças questionários'));
      expect(pt, contains('Nunca escrevas um plano de dia completo'));
      expect(pt, contains('Faz perguntas só quando o utilizador pedir'));
      expect(
        pt,
        contains('Só falas de nutrição, treino e dos dados desta app'),
      );
      expect(pt, contains('Não escrevas kcal'));
    },
  );

  test('the English prompt has the same scope and brevity rules', () {
    final en = buildAssistantPrompt(
      question: 'What time is it?',
      context: context,
      english: true,
    );
    expect(en, contains('Answer only what was asked'));
    expect(en, contains('Do not start questionnaires'));
    expect(en, contains('Never write a full-day plan'));
    expect(en, contains('Only talk about nutrition, training'));
    expect(en, contains('Do not write kcal'));
    expect(en, isNot(contains('what they have at home')));
  });
}
