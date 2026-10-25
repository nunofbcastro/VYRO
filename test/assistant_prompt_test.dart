import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';

void main() {
  const context = AssistantContext(
    goal: 'Força',
    kcalGoal: 2400,
    proteinGoal: 150,
    kcalToday: 1200,
    proteinToday: 70,
    foodsToday: ['Iogurte', 'Barra de aveia'],
    nextWorkout: 'Superior A',
    nextWorkoutDay: 'Quarta-feira',
    weekDone: 1,
    weekTotal: 4,
  );

  test('prompt carries safety rules, local data and the question', () {
    final prompt = buildAssistantPrompt(
      question: 'O que janto?',
      context: context,
    );
    expect(prompt, contains('português de Portugal'));
    expect(prompt, contains('conselhos médicos'));
    expect(prompt, contains('2400 kcal, 150 g proteína'));
    expect(prompt, contains('Iogurte, Barra de aveia'));
    expect(prompt, contains('Superior A (Quarta-feira)'));
    expect(prompt, contains('1/4 treinos'));
    expect(prompt.trimRight(), endsWith('Assistente:'));
    expect(prompt, contains('Utilizador: O que janto?'));
  });

  test('history is trimmed and empty facts are omitted', () {
    final history = [
      for (var i = 0; i < 10; i++) ChatTurn(fromUser: i.isEven, text: 'msg $i'),
    ];
    final prompt = buildAssistantPrompt(
      question: 'Next?',
      context: const AssistantContext(),
      history: history,
      english: true,
      maxHistory: 4,
    );
    expect(prompt, isNot(contains('msg 5')));
    expect(prompt, contains('msg 6'));
    expect(prompt, contains('msg 9'));
    expect(prompt, isNot(contains('Goal:')));
    expect(prompt, contains('medical advice'));
  });

  test('status parsing falls back to unavailable', () {
    expect(LlmStatus.parse('available'), LlmStatus.available);
    expect(LlmStatus.parse('downloadable'), LlmStatus.downloadable);
    expect(LlmStatus.parse(null), LlmStatus.unavailable);
    expect(LlmStatus.parse('weird'), LlmStatus.unavailable);
  });
}
