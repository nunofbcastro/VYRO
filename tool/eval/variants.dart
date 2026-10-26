/// Strategies and prompt variants for the offline evaluation. Everything here
/// lives in `tool/eval`; the app code is only read, never changed.
///
/// Variants are applied where the app talks to the model: the harness answers
/// the `describeImage` channel call, rewrites the prompt when needed and calls
/// the local model. The parsing, screening, verification and fusion are the
/// app's own code.
library;

import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// Every strategy name the harness accepts.
const strategyNames = <String>[
  'pipeline',
  'system_only',
  'no_verify',
  'sc_union',
  'sc_inter',
  'checklist',
  'pt_prompt',
  'en_names',
  'legacy_app',
  'regions_only',
];

/// `self_consistency_2` is shorthand for both self-consistency variants.
List<String> expandStrategies(Iterable<String> requested) {
  final out = <String>[];
  for (final raw in requested) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final expanded = name == 'self_consistency_2'
        ? const ['sc_union', 'sc_inter']
        : [name];
    for (final e in expanded) {
      if (!strategyNames.contains(e)) {
        throw ArgumentError(
          'unknown strategy "$e" (known: ${strategyNames.join(', ')}, '
          'self_consistency_2)',
        );
      }
      if (!out.contains(e)) out.add(e);
    }
  }
  return out;
}

/// Which app prompt a channel call carries.
enum PromptKind { first, second, verify, other }

/// Two-view requests get an extra paragraph appended by the app; it is kept
/// as a suffix so the base prompt can be recognised and rewritten.
const _twoViewMarker = '\nBoth images show the SAME meal';

({String base, String suffix}) splitTwoViewSuffix(String prompt) {
  final cut = prompt.indexOf(_twoViewMarker);
  if (cut < 0) return (base: prompt, suffix: '');
  return (base: prompt.substring(0, cut), suffix: prompt.substring(cut));
}

PromptKind kindOf(String base) {
  if (base == buildFoodPhotoPrompt()) return PromptKind.first;
  if (base == buildFoodSecondChancePrompt()) return PromptKind.second;
  if (base.contains('Check each numbered item')) return PromptKind.verify;
  return PromptKind.other;
}

/// Draft item names from a verification prompt ("0: ovo" lines).
List<String> verifyItemsOf(String base) => [
  for (final line in base.split('\n'))
    if (RegExp(r'^\d+: ').hasMatch(line))
      line.substring(line.indexOf(': ') + 2),
];

/// Historical: the first-look prompt before 0.6.2 (category checklist), reconstructed from
/// git history: `git show a7a8778^:lib/features/nutrition/food_vision/system_food_vision.dart`.
String checklistFirstPrompt() => '''
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods or portions from earlier images, messages or meals.
List distinct foods and drinks actually visible in this photo, including the edges. Check protein, starches, legumes, vegetables, fruit, drinks and visible spreads. This checklist is not evidence: omit anything you cannot see. Do not infer hidden ingredients, oil, sugar or milk.
One row per food type, with its TOTAL count. List a drink only once per visible cup/glass; a handle, saucer, reflection or shadow is not another cup. Do not list the same coffee as both espresso and coffee with milk. If the count is uncertain use 1.
For each item give:
- "name": short food name in European Portuguese, not the name of the whole dish.
- "count": number of clearly separate edible pieces or drink containers, else 1.
- "size": small, medium or large compared with a typical single serving of that food. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: {"items":[{"name":"...","count":1,"size":"medium"}]}''';

/// Historical (before 0.6.7): the app's three prompts written in European
/// Portuguese (same JSON keys and answer format, so the parser and verifier
/// work unchanged). Used by the `pt_prompt` strategy only.
String ptFirstPrompt() => '''
Analisa APENAS a imagem anexada a ESTE pedido. É uma refeição nova e independente. Nunca reutilizes alimentos de imagens, mensagens ou refeições anteriores.
Indica apenas os alimentos e bebidas que estão mesmo nesta fotografia. Inclui cada bebida que esteja num copo, chávena, garrafa ou lata, e cada alimento num prato, tábua ou embalagem. Um alimento servido ou fotografado numa frigideira, panela, tabuleiro, caixa, embalagem ou na mão continua a ser alimento: indica o alimento, nunca o recipiente. Não acrescentes acompanhamentos, saladas, legumes, leguminosas, molhos ou guarnições que não se vejam claramente. Não deduzas ingredientes escondidos, azeite, açúcar ou leite. Não indiques objetos que não são alimentos, como a mesa, guardanapos, toalhas ou talheres.
Uma linha por tipo de alimento, com a contagem TOTAL. Uma chávena ou um copo é UMA bebida, mesmo com pires, asa ou reflexo. Nunca indiques o mesmo café duas vezes.
Para cada item indica:
- "name": o nome específico do alimento ou da bebida em português europeu (Portugal), por exemplo "ovo", "cerveja", "bife de vaca grelhado", "sidra", "batatas fritas". Nunca em inglês, nem palavras genéricas como "bebida" ou "comida" quando se vê o tipo.
- "where": localização curta na fotografia, em português europeu, por exemplo "centro do prato" ou "copo em cima à esquerda". Serve para verificar o item; deixa "" se não conseguires saber.
- "count": número de peças ou recipientes claramente separados, senão 1.
- "size": pequeno, médio ou grande, comparado com uma porção típica desse alimento. Não indiques gramas.
Se não se vir nenhum alimento ou bebida, responde {"items":[]}.
Responde apenas com JSON, sem markdown: {"items":[{"name":"...","where":"...","count":1,"size":"medio"}]}''';

String ptSecondPrompt() => '''
Olha outra vez APENAS para a imagem anexada a ESTE pedido. É uma refeição nova e independente, e a primeira análise não encontrou alimentos. As fotografias de refeições são difíceis de ler: a comida pode estar numa frigideira, panela, tabuleiro, caixa, embalagem ou tábua, ou só parcialmente comida.
Indica os principais alimentos e bebidas que vês, mesmo que não tenhas a certeza do prato exato. Indica o próprio alimento, não a frigideira, a caixa ou a embalagem à volta. Não indiques objetos que não são alimentos, como a mesa, guardanapos, toalhas ou talheres. Se não vires mesmo nenhum alimento ou bebida, responde {"items":[]}.
Para cada item indica "name" (nome do alimento em português europeu (Portugal), nunca em inglês), "where" (localização curta em português europeu, por exemplo "centro da frigideira", ou "" se não tiveres a certeza), "count" (1 se não tiveres a certeza) e "size" (pequeno, médio ou grande). Não indiques gramas.
Responde apenas com JSON, sem markdown: {"items":[{"name":"...","where":"...","count":1,"size":"medio"}]}''';

String ptVerifyPrompt(List<String> items) {
  final numbered = [
    for (var i = 0; i < items.length; i++) '$i: ${items[i]}',
  ].join('\n');
  return '''
Olha APENAS para a fotografia anexada (qualquer vista dela anexada). Verifica cada item numerado abaixo.
Responde "visible": true se esse alimento ou bebida se vê NESTA fotografia, mesmo parcialmente, pequeno ou na margem da imagem.
Responde "visible": false apenas se tiveres a certeza de que NÃO está na fotografia. Se tiveres dúvidas, responde true.
Não nomeies outros alimentos e não mudes os nomes dos itens.
$numbered
Responde apenas com JSON, sem markdown, uma entrada por item: {"checks":[{"i":0,"visible":true}]}''';
}

/// `en_names` (and `pipeline`, `system_only`): since 0.6.7 the app's own
/// prompts ask for English names and locations, so this variant is the app
/// prompt itself. Kept as an alias so older run scripts and labels still work.
/// Measured on eval/datasets/nutrition5k_50 (gemma3n:e2b): F1 0.47, against
/// 0.35 with the European Portuguese prompts (`pt_prompt` below, which is
/// historical and no longer the app's prompt).
String enFirstPrompt() => buildFoodPhotoPrompt();

/// `en_names` second look: the app's second-chance prompt (English names).
String enSecondPrompt() => buildFoodSecondChancePrompt();

/// The variant's prompt for one app prompt. The verify prompt has no name
/// field and is already in English, so it goes to the model unchanged.
String enNamesPrompt(PromptKind kind, String base) => switch (kind) {
  PromptKind.first => enFirstPrompt(),
  PromptKind.second => enSecondPrompt(),
  PromptKind.verify || PromptKind.other => base,
};

/// `legacy_app`: the first-look prompt as committed in git HEAD (European
/// Portuguese names, before the English-name change). Verbatim from
/// `git show HEAD:lib/features/nutrition/food_vision/system_food_vision.dart`
/// (`buildFoodPhotoPrompt()`), with the HEAD `_jsonFormat` expanded.
String legacyFirstPrompt() => '''
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods from earlier images, messages or meals.
List only the foods and drinks that are actually in this photo. Include every drink in a glass, cup, bottle or can, and every food on a plate, board or packaging. Food can also be served or photographed in a pan, pot, tray, box, packaging or hand: still list the food, not the container. Never add side dishes, salads, vegetables, legumes, spreads or garnishes that are not clearly visible. Do not infer hidden ingredients, oil, sugar or milk. Do not list non-food objects such as the table, napkins, towels or cutlery.
One row per food type, with its TOTAL count. A single cup or glass is ONE drink, even with a saucer, handle or shadow. Never list the same coffee twice.
For each item give:
- "name": the specific food or drink name in European Portuguese (Portugal), e.g. "ovo", "cerveja", "bife de vaca grelhado", "sidra", "batatas fritas". Never English, never a general word such as "bebida" or "comida" when the kind is visible.
- "where": short location in the photo in European Portuguese, e.g. "centro do prato" or "copo em cima à esquerda". It helps us check the item; leave it as "" if you cannot tell.
- "count": number of clearly separate pieces or containers, else 1.
- "size": small, medium or large compared with a typical single serving. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: {"items":[{"name":"...","where":"...","count":1,"size":"medium"}]}''';

/// `legacy_app` second look: the second-chance prompt as committed in git
/// HEAD (`buildFoodSecondChancePrompt()`), verbatim, `_jsonFormat` expanded.
String legacySecondPrompt() => '''
Look again ONLY at the image attached to THIS request. It is a new, independent meal, and a first look found no food. Meal photos are often hard to read: food can be in a pan, pot, tray, box, packaging or on a board, or only partly eaten.
Name the main food(s) and drink(s) you can see, even if you are not sure of the exact dish. Name the food itself, not the pan, box or packaging around it. Do not list non-food objects such as the table, napkins, towels or cutlery. If you truly see no food or drink, reply {"items":[]}.
For each item give "name" (the food name in European Portuguese (Portugal), never English), "where" (short location in European Portuguese, e.g. "centro da frigideira", or "" if unsure), "count" (1 if unsure) and "size" (small, medium or large). Do not output grams.
Reply with JSON only, no markdown: {"items":[{"name":"...","where":"...","count":1,"size":"medium"}]}''';

/// `legacy_app` variant for one app prompt. The verify prompt is unchanged in
/// HEAD and in the working tree, so it goes to the model as it is.
/// Matching and the database are the current ones: this isolates the prompt
/// change only.
String legacyNamesPrompt(PromptKind kind, String base) => switch (kind) {
  PromptKind.first => legacyFirstPrompt(),
  PromptKind.second => legacySecondPrompt(),
  PromptKind.verify || PromptKind.other => base,
};
