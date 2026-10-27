import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/assistant/domain/local_assistant.dart';
import 'package:vyro/features/assistant/domain/model_answer.dart';
import 'package:vyro/features/assistant/widgets/answer_footnote.dart';
import 'package:vyro/features/assistant/widgets/chat_message_bubble.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';

void main() {
  final foods = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  // Monday 26 October 2026, 14:32 local time.
  final now = DateTime(2026, 10, 26, 14, 32);
  const context = AssistantContext(kcalGoal: 2000, kcalToday: 1500);

  LocalAssistantAnswer? ask(String q, {bool english = false}) =>
      answerLocally(q, context, foods, english: english, now: now);

  group('local intents', () {
    test('time question uses the device clock, PT-PT', () {
      for (final q in [
        'Que horas são?',
        'que horas sao',
        'Que horas são agora?',
      ]) {
        final answer = ask(q);
        expect(answer, isNotNull, reason: q);
        expect(answer!.text, 'São 14h32.');
        expect(answer.proposal, isNull);
      }
    });

    test('time question in English', () {
      expect(ask('What time is it?', english: true)!.text, 'It is 2:32 PM.');
    });

    test('date and weekday question', () {
      expect(
        ask('Que dia é hoje?')!.text,
        'Hoje é segunda-feira, 26 de outubro de 2026.',
      );
      expect(
        ask('What day is it today?', english: true)!.text,
        'Today is Monday, October 26, 2026.',
      );
    });

    test('greetings get a short help line, not a plan', () {
      for (final q in ['Olá', 'Bom dia!', 'boa noite']) {
        final answer = ask(q);
        expect(answer, isNotNull, reason: q);
        expect(answer!.text, startsWith('Olá!'));
        expect(answer.text, contains(localAssistantHelp(false)));
        expect(answer.proposal, isNull);
      }
    });

    test(
      'a greeting followed by an out-of-scope question is not swallowed',
      () {
        const q = 'Bom dia, quem foi o presidente?';
        expect(isOutOfScope(q), isTrue);
        expect(ask(q)!.text, localScopeReply(false));
      },
    );
  });

  group('scope gate', () {
    test('clearly outside questions get the scope reply, no proposal', () {
      for (final q in [
        'Qual é a capital de França?',
        'Quem foi o presidente dos EUA?',
        'Escreve um poema sobre o mar',
        'Conta-me uma piada',
        'Quais são as notícias de hoje?',
      ]) {
        final answer = ask(q);
        expect(answer, isNotNull, reason: q);
        expect(answer!.text, localScopeReply(false));
        expect(answer.proposal, isNull);
      }
    });

    test('the scope reply gives example questions', () {
      final text = localScopeReply(false);
      expect(text, contains('nutrição'));
      expect(text, contains('treino'));
      expect(text, contains('O que me falta hoje?'));
    });

    test('nutrition, training and borderline questions reach the model', () {
      for (final q in [
        'Sugere um jantar com proteína',
        'O que janto hoje?',
        'Quanto proteína preciso?',
        'Que treino tenho a seguir?',
        'Posso treinar com dores nas costas?',
        'Quem é o meu treinador?',
      ]) {
        expect(isOutOfScope(q), isFalse, reason: q);
      }
    });
  });

  test('hour formats', () {
    expect(localTimeAnswer(DateTime(2026, 1, 1, 1, 5), false), 'É 1h05.');
    expect(localTimeAnswer(DateTime(2026, 1, 1, 0, 0), false), 'São 0h00.');
    expect(
      localTimeAnswer(DateTime(2026, 1, 1, 0, 7), true),
      'It is 12:07 AM.',
    );
  });

  testWidgets('footnote is one muted line with an info icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnswerFootnote(
            text:
                'Algumas frases foram retiradas: os números não coincidiam com a base local.',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(
      find.textContaining('Algumas frases foram retiradas'),
      findsOneWidget,
    );
  });

  testWidgets('no protocol fragments reach the rendered bubble', (
    tester,
  ) async {
    final composed = composeModelAnswer(
      'Aqui tens uma ideia.\n'
      '[[MEAL]]{"meal":"dinner","items":[{"name":"Peito de frango","grams":150}]}[[/MEAL]]\n'
      'Mantém a porção simples.\n'
      '[[MEAL]]{"meal":"din',
      foods,
      english: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            turn: ChatTurn(fromUser: false, text: composed.text),
          ),
        ),
      ),
    );
    expect(find.textContaining('[['), findsNothing);
    expect(find.textContaining('{"'), findsNothing);
    expect(find.textContaining('Aqui tens uma ideia.'), findsOneWidget);
  });
}
