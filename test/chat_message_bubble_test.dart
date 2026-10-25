import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/assistant/widgets/chat_message_bubble.dart';

void main() {
  Future<void> pumpMessage(
    WidgetTester tester,
    String text, {
    bool fromUser = false,
    bool light = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: light ? VyroTheme.light : VyroTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageBubble(
                turn: ChatTurn(fromUser: fromUser, text: text),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String renderedText(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((widget) => widget.data ?? widget.textSpan!.toPlainText())
      .join('\n');

  testWidgets('AI headings, emphasis and lists display without Markdown syntax', (
    tester,
  ) async {
    await pumpMessage(
      tester,
      '## O teu jantar\n\n**Proteína** e *legumes*.\n\n- Frango\n- Arroz\n\n1. Confirmar\n2. Guardar',
    );
    final text = renderedText(tester);
    expect(text, contains('O teu jantar'));
    expect(text, contains('Proteína e legumes.'));
    expect(text, contains('Frango'));
    expect(text, contains('Confirmar'));
    expect(text, isNot(contains('##')));
    expect(text, isNot(contains('**')));
    expect(text, isNot(contains('*legumes*')));
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.selectable, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user messages retain literal Markdown characters', (
    tester,
  ) async {
    const input = 'Explica **isto** e # este sinal';
    await pumpMessage(tester, input, fromUser: true);
    expect(find.byType(MarkdownBody), findsNothing);
    expect(renderedText(tester), input);
  });

  testWidgets('tables and code fit narrow screens with enlarged text', (
    tester,
  ) async {
    await pumpMessage(tester, '''| Alimento | Porção | Energia |
| --- | --- | --- |
| Peito de frango grelhado | 120 gramas | 198 kcal |

`kcal` por porção:

```text
calorias = quantidade_em_gramas * calorias_por_100_gramas / 100
```

> Confirma a porção antes de guardar.
''', scale: 1.6);
    expect(find.byType(Table), findsOneWidget);
    expect(renderedText(tester), contains('Peito de frango grelhado'));
    expect(renderedText(tester), isNot(contains('```')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Markdown images stay text and never load remote or local images', (
    tester,
  ) async {
    await pumpMessage(
      tester,
      '![Refeição](https://example.invalid/photo.jpg)\n\n![Local](/private/photo.jpg)',
    );
    expect(find.byType(Image), findsNothing);
    expect(renderedText(tester), contains('Refeição'));
    expect(renderedText(tester), contains('Local'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain replies and formatted links work in the light theme', (
    tester,
  ) async {
    await pumpMessage(
      tester,
      'Olá!\n\nConsulta [a fonte](https://example.invalid).',
      light: true,
    );
    expect(renderedText(tester), contains('Olá!'));
    expect(renderedText(tester), contains('Consulta a fonte.'));
    expect(renderedText(tester), isNot(contains('](')));
    expect(tester.takeException(), isNull);
  });
}
