# Reconhecimento de alimentos por fotografia

Tudo corre **no telemóvel**: a foto não sai do dispositivo, não há API paga
nem servidor. O reconhecimento só **sugere** alimentos e porções; os nutrientes
vêm sempre da base offline (`docs/NUTRITION_DATA.md`) e o utilizador confirma
tudo antes de guardar. Nenhum valor de calorias vem diretamente da imagem.

## Pipeline

```
foto (câmara/galeria, ficheiro temporário apagado logo após leitura)
  │  opcional: 2.ª foto (outro ângulo) ou recorte de uma região da 1.ª
  ▼ FoodVisionPipeline (lib/features/nutrition/food_vision/system_food_vision.dart)
  │
  ├─ ramo offline (sempre tentado, isolado do ramo do sistema)
  │     RegionFoodVision: classificador AIY Food V1 em 26 recortes
  │     (imagem completa + grelhas 3×3 e 4×4), recortes em letterbox
  │     etiquetas → alimentos via vision_labels do TSV
  │
  ├─ ramo do sistema (só se OnDeviceLlm.status() == available)
  │     SystemFoodVision: Gemini Nano multimodal (Android, ML Kit GenAI Prompt API)
  │       1.ª passagem (`buildFoodPhotoPrompt`): só a imagem atual, sem lista
  │         de categorias → {items:[{name,where,count,size}]}, nomes e "where" em inglês (0.6.7);
  │         só alimentos e bebidas da foto; todas as bebidas em copo/chávena/garrafa/lata
  │         e todos os alimentos em pratos/tábuas/embalagens; "where" pedido mas opcional
  │       regras determinísticas (`applyDrinkSanity`): uma chávena = uma bebida;
  │         o café duplicado vai para sugestões (fora dos totais)
  │       2.ª passagem (`buildFoodVerifyPrompt`): verificação, não revisão. Recebe
  │         a lista e devolve {checks:[{i,visible}]}. Só remove itens (visible=false);
  │         nunca acrescenta nem renomeia. Resposta inválida ou incompleta →
  │         mantém a lista da 1.ª passagem ("verify: unparsed" em detalhes).
  │         Todos rejeitados → mantêm-se TODOS como incertos ("verify rejected
  │         all — kept as uncertain"); a verificação nunca esvazia uma lista não vazia
  │       1.ª passagem vazia ({"items":[]}) → 2.ª tentativa (`buildFoodSecondChancePrompt`):
  │         comida pode estar na frigideira, panela, tabuleiro, caixa ou embalagem,
  │         ou parcialmente comida; nomeia os alimentos e bebidas visíveis.
  │         Só se também vier vazia é "refeição vazia confirmada" (`confirmedEmpty`).
  │         Detalhes: "first: empty → second chance: ..."
  │       cada pedido repete-se 1× se o AICore estiver ocupado; o erro e a
  │       resposta crua ficam em "Detalhes da análise"
  │
  ├─ falhas independentes: se um ramo falhar, o outro continua (aviso
  │   "systemFailed"); se os dois falharem, ou se a revisão ficar vazia sem confirmação, aparece o cartão de falha com "Tentar de novo" (`VisionFailure`)
  │   **Sem resposta do modelo do sistema (falha, ocupado, indisponível, sem AICore):
  │   o offline entra só como SUGESTÕES** (`offlineHypothesesOnly`, 0.6.8). A lista
  │   principal fica vazia, o total é 0 kcal, o cartão de falha explica que as
  │   sugestões são pouco fiáveis e a fonte mostra "Reconhecimento offline (pouco fiável)".
  │   Motivo: ver "Avaliação offline" abaixo (precisão 0,28, recall 0,06).
  │
  ▼ fuseVisionResults: alimentos do sistema primeiro; alimentos do offline que
    coincidem ficam "corroborados"; os restantes são SUGESTÕES fora dos totais
    até o utilizador os aceitar ("Outras hipóteses"). Mesmo com refeição vazia
    confirmada, as sugestões do offline continuam visíveis; a lista principal
    nunca recebe alimentos do offline.
  │
  ▼ PhotoFoodPage: lista editável (trocar alimento, porção, remover, adicionar,
    sugestões rápidas), totais kcal/P/H/G, refeição, "Adicionar N ao diário"
```

Uma nova fotografia substitui a revisão anterior. A seleção/análise fica
bloqueada durante outro pedido ou gravação; resultados tardios de páginas
fechadas são ignorados.

## Resultados progressivos, tempos e nomes

**Rascunho e final.** `FoodVisionPipeline.analyseProgressive(bytes)` (ou
`analyseViewsProgressive(primeira, segunda)`) devolve um `Stream<FoodVisionResult>`:

1. **Rascunho** (`stage: VisionStage.draft`), assim que a 1.ª resposta do modelo
   do sistema é lida e filtrada (não-alimentos e coerência de café já aplicados).
   Os itens têm `pending: true`. Se o ramo offline já tiver terminado, as suas
   hipóteses entram nas sugestões do rascunho; caso contrário ficam para o final.
2. **Final** (`stage: VisionStage.final_`), depois da verificação e da fusão. É o
   mesmo resultado que `analyse()` devolve. A verificação só **remove** itens do
   rascunho; nunca acrescenta. Sem modelo do sistema não há rascunho, só o final.
   Erros chegam como erro do stream (o mesmo que `analyse()` lançaria).

`analyse()` e `analyseViews()` continuam a devolver só o final.

**Tempos.** `FoodVisionResult.timings` guarda a duração de cada fase (`first`,
`second` quando há segunda tentativa, `verify`, `regions`). A última linha de
`detail` resume-os, por exemplo `timing: first 2.1 s, verify 1.8 s, regions 0.9 s`.
O ramo offline arranca logo no início, em paralelo com a verificação de qualidade
e o modelo do sistema.

**Nomes antes da correspondência** (`food_names.dart`, `matchFoodName`). Primeiro,
o **nome em inglês** é comparado só com o nome inglês e os aliases da base
(`matchEnglishFoodName`), com as formas singular/plural em inglês (`englishNameVariants`:
almond → almonds, berries → berry). Só se não houver correspondência, a base é
consultada com estas formas, por ordem, e a primeira que corresponder ganha:
1. o nome como o modelo o escreveu (o original tem sempre prioridade);
2. o nome normalizado (minúsculas, sem acentos);
3. uma tradução inglês → português (`englishFoodNames`: egg → ovo, beer → cerveja,
   cider → sidra, steak → bife, fries → batatas fritas, sparkling water → água com gás,
   etc.). Para "water" usa-se **água mineral**, porque "água" sozinho cai em
   "Água com gás" (ordem da base);
4. formas singulares portuguesas: `-aes/-oes` → `-ao` (pães, limões), `-ns` → `-m`
   (atuns), `-is` → `-l`, `-es`/`-as`/`-os`/`-s` (tomates, batatas, ovos, morangos).
   Primeiro todas as palavras no plural, depois só a última.

Palavras genéricas em inglês ("beverage", "dish", "snack") são nomes genéricos:
ficam como "Que bebida?" / "Que comida?" e não recebem nutrientes.

Os prompts pedem o nome e o "where" **em inglês** (ver "Decisão de idioma" abaixo).
Um nome sem correspondência na base **nunca** é o título do cartão: aparece
"Que alimento?" (ou "Que bebida?" para genéricos) com "Escolhe o alimento"; o nome
original fica só em "Detalhes da análise (técnico)". O "where" em inglês só aparece
na interface em inglês; em português fica nos detalhes técnicos.

**Decisão de idioma (0.6.7).** Avaliação offline em `eval/datasets/nutrition5k_50`
(50 fotos, pipeline real da app, gemma3n:e2b como proxy do Gemini Nano), com a mesma
lógica de análise e só o prompt a mudar:

| Variante (`tool/eval/variants.dart`) | F1 | Precisão | Recall | FP/foto | Erros de análise |
| --- | --- | --- | --- | --- | --- |
| prompts da app antes de 0.6.7 (nomes em português europeu) | 0,35 | 0,37 | 0,33 | 1,64 | — |
| nomes em inglês (`en_names`, agora os prompts da app) | **0,47** | 0,48 | 0,45 | 1,44 | 0 |
| prompts inteiramente em português (`pt_prompt`, histórica) | 0,29 | — | — | — | — |

Também medidos e **sem ganho**: autoconsistência com 2 amostras (`sc_union`,
`sc_inter`) e o checklist de categorias antigo (`checklist`). Decisão: os prompts da
app pedem nomes curtos, comuns e no singular em inglês (ex.: "fried egg", "beer",
"white rice", "beef steak"). As restantes regras (JSON, não-alimentos, uma chávena =
uma bebida, panela/embalagem) mantêm-se como estavam. O texto exato está em
`buildFoodPhotoPrompt` e `buildFoodSecondChancePrompt` (`system_food_vision.dart`) e
é igual ao antigo `en_names`. A verificação já era em inglês e não muda.
Nota: a medição foi feita com gemma3n:e2b, não com o Gemini Nano no telemóvel; a
precisão no dispositivo continua por medir.

**Sugestões de acompanhamento** (`food_companions.dart`). Depois da verificação,
os nomes confirmados sugerem molhos e acompanhamentos, sem perguntar ao modelo:

- carne, bife → molho castanho (gravy; o alias "molho de cerveja" é o
  mesmo registo da base), natas, maionese, ketchup (se existir na base);
- massa, esparguete, lasanha → natas, molho de tomate e queijo ralado (se existirem);
- batata frita → ketchup, maionese;
- salada, alface → azeite.

São **sugestões** (`suggestions`), fora dos totais, e só aparecem se existirem na
base. Não se repetem alimentos já listados nem os cafés duplicados. Na base atual,
o ketchup, o molho de tomate e o queijo ralado não existem, por isso não aparecem.

**Hambúrgueres** (`burger_rules.dart`, puro Dart, testado em
`test/burger_rules_test.dart`):

- Em inglês, «hamburger», «burger», «cheeseburger», «big mac» são o hambúrguer
  completo (`cheeseburger_whole`, com pão). «beef patty» e «patty» são a carne
  (`beef_ground_patty`).
- Sanduíche mais pão à parte: o modelo listou um hambúrguer completo e também um
  pão ou um pão de hambúrguer. O pão já está no sanduíche, por isso o sanduíche
  passa a carne (120 g por unidade; a contagem mantém-se). O pão não é contado
  duas vezes.
- Carne sem pão: a lista principal não tem pão, por isso o pão de hambúrguer
  (`hamburger_bun`) é sugerido primeiro; depois queijo (`cheese_gouda`) e molho
  (`burger_sauce`), se ainda não estiverem na lista. São sugestões, fora dos
  totais.
- Contagem: «2 hamburgers» são dois hambúrgueres completos, 300 g (150 g
  por unidade, sem fator de tamanho).

## Porções e peças — `portion_estimate.dart`

- A única função que calcula gramas é `estimatedGrams`.
- Alimento com `portion_units` no TSV (ex.: 3 sardinhas = 120 g): gramas =
  `portion_g × peças ÷ portion_units × fator`. Três sardinhas dão 120 g, não 360 g.
- Alimento sem `portion_units` (arroz, sopas, pratos): a contagem **não**
  multiplica; só o tamanho aplica.
- Fator de tamanho: pequeno 0,6; médio 1; grande 1,5. Peças limitadas a 1–20.
- Limites finais: 5–1500 g. Alimento não reconhecido: usa um `grams` do modelo
  se existir (limitado), senão 100 g × peças × fator.
- **Pratos inteiros** (`isWholeDish`: categoria `pratos`, pizza, hambúrguer,
  francesinha): um tamanho "pequeno" não os reduz abaixo de uma porção típica
  (fator mínimo 1). "Grande" usa 1,5 × a porção da base.
- Limite conhecido: a porção da base da pizza é **uma fatia** (110 g). Uma pizza
  inteira com contagem 1 fica ~165 g em "grande", ainda subestimada. Uma linha
  "pizza inteira" na base (ficheiro TSV, outro responsável) resolveria isto; o
  código não o inventa.
- Estas gramas são **estimativas editáveis**, não medições.

## Fallback offline — `RegionFoodVision`

- Modelo: `assets/models/aiy_food_v1.tflite` (Google AIY Food V1, Apache 2.0,
  entrada 1×192×192×3 uint8, saída 2024 classes uint8, índice 0 = fundo) com
  `aiy_food_v1_labels.csv`.
- É um classificador de **pratos** (uma etiqueta por imagem), não um detetor de
  ingredientes. Por isso classifica 26 recortes e soma as evidências.
- Cada recorte é colocado em letterbox (sem distorcer proporções) antes de
  entrar no modelo.
- Regras (constantes na classe): etiqueta conta se p ≥ 0,08 (top-5 por região);
  alimento fica se o pico ≥ 0,14 e apareceu em ≥ 2 regiões distintas; várias
  etiquetas do mesmo alimento num recorte contam apenas uma vez; no máximo 6;
  apenas um alimento por categoria exclusiva (`carne`, `peixe`, `leguminosas`).
- Gramas = porção típica do alimento (sem contar peças nem tamanho).
- Corre num isolate persistente (criado na primeira análise e libertado após
  inatividade) para não bloquear o ecrã e evitar recriar o interpreter a cada foto.
- Resultado com o prato de exemplo (arroz, feijão, frango, alface, tomate):
  feijão, alface, tomate, frango e arroz. Noutras fotos pode falhar ou
  sugerir alimentos errados — por isso a revisão é obrigatória.
- **Porta de não-alimentos (0.6.8).** O índice 0 do CSV é `__background__`. Antes
  era descartado antes do ranking, por isso o classificador "adivinhava" sempre um
  prato. Agora cada recorte guarda a probabilidade bruta de fundo. Um recorte
  vota "sem comida" quando o fundo é mais provável do que a melhor etiqueta de
  alimento desse recorte (ou quando nenhuma etiqueta chega a 0,08). Se mais de
  metade dos 26 recortes votar assim (`nonFoodRegionShare` = 0,5, ou seja, ≥ 14),
  a foto não tem alimento reconhecível: o resultado offline fica vazio, sem
  sugestões, com a nota `offlineNoFood` ("Nenhum alimento reconhecido nesta foto").
  Um empate (13 de 26) não conta como "a maioria". Os limites de sugestão são os
  mesmos de sempre: pico ≥ 0,14 e ≥ 2 regiões (`minFoodPeak`, `minRegions`).
  Limite: a porta não foi calibrada em fotos sem comida (o conjunto de 50 fotos
  só tem pratos); o efeito real num objeto como uma bola de madeira precisa de
  medição no dispositivo.

## Avaliação offline (0.6.8) — motivo das sugestões

Conjunto `eval/datasets/nutrition5k_50` (50 fotos de pratos reais; resultados em
`eval/datasets/nutrition5k_50/results/*regions_only*`), só o ramo offline
(`RegionFoodVision`), sem o modelo do sistema:

| Métrica | Valor |
| --- | --- |
| Precisão | 0,28 (8 de 29) |
| Recall | 0,06 (8 de 140) |
| F1 | 0,09 |
| Falsos positivos por foto | 0,42 (21 no total) |
| Refeições exatas | 0 |

Com precisão e recall destes valores, o offline **não pode** adicionar alimentos
à lista principal sem confirmação. Foi também o caso real de uma foto de uma bola
de madeira (sem comida) que devolveu "Alface" (50 g, 8 kcal) na lista principal
com "Adicionar 1 ao diário". Por isso (0.6.8):

- sem resposta do modelo do sistema, todos os alimentos offline vão para
  "Outras hipóteses" (`offlineHypothesesOnly` em `food_vision.dart`); a lista
  principal fica vazia e o CTA fica em 0;
- a porta de não-alimentos devolve nada quando o fundo domina (ver acima);
- com resposta do modelo do sistema, nada muda: os alimentos offline só
  corroboram ou ficam como sugestões (`fuseVisionResults`).

## IA do sistema — `SystemFoodVision`

- Android: `OnDeviceLlmChannel.describeImage` (Kotlin) →
  `generateContentRequest(ImagePart(jpeg), TextPart(prompt))` com temperatura
  0,1 e uma única resposta candidata. Respostas alternativas nunca se concatenam.
  Requer AICore/Gemini Nano (ex.: Pixel 9+, Galaxy S25+). A imagem é reduzida
  a 768 px e fica só em memória.
- Para a 2.ª foto, o pedido envia as duas imagens e instrui o modelo a reconciliar
  identidades sem somar contagens entre vistas.
- O prompt (inglês desde 0.6.7) pede o nome, o local de cada item ("where"),
  contagens e tamanho relativo
  (pequeno/médio/grande), não gramas. Não há lista de categorias (proteína,
  leguminosas, saladas...): essa lista fazia o modelo preencher todas as
  categorias. Uma chávena, asa, pires ou reflexo não são recipientes separados.
  Linhas repetidas do mesmo alimento conservam o maior total, sem somar duplicados.
- Verificação sem acrescentos e só com prova de ausência: o modelo responde
  `visible: false` apenas quando tem a certeza de que o item não está na foto.
  Visível, mesmo parcialmente, pequeno ou no canto da imagem, é `true`. Um índice
  omitido ou sem verdicto booleano **mantém o item na lista principal** como
  incerto ("Hipótese a confirmar"). Uma resposta sem lista `checks` mantém a
  primeira lista inteira (ver "Regras de confiança" abaixo).
- Diagnóstico: "Detalhes da análise" tem uma linha por item, por exemplo
  `cerveja → kept (verify=true, where "top right", drink, no container in where)`,
  `toalha → dropped (non-food)`, `Café com leite → suggestion (duplicate coffee)`,
  `Queijo → dropped (verify=false)`. É o texto a enviar para revisão.
- Regras determinísticas depois da verificação (`system_food_vision.dart`):
  - Um café por chávena: se aparecerem um café tipo expresso e um tipo café com
    leite, fica só o primeiro listado pelo modelo; o outro vai para sugestões
    (fora dos totais). A categoria vem da chave da
    base (`espresso`, `coffee_with_milk`) ou, se não houver match, do nome
    (café com leite/galão/meia de leite; café/expresso/bica).
  - Contagem só para alimentos com porção por unidade (`portion_units` no TSV).
    Feijão, alface, arroz e molhos contam como 1, para que "2 unid." não duplique
    a porção. `estimatedGrams` já ignorava a contagem sem `portion_units`.
- Iterações anteriores, testadas num telemóvel real, deram frango ×2, arroz e
  tomate, mas falharam feijão e alface e inventaram laranja. Num telemóvel real,
  uma foto com duas fatias de pão torrado e um café expresso devolveu 7 alimentos
  (incluindo café com leite, feijão, alface e tomate): a lista de categorias e a
  revisão que repetia o prompt inteiro foram a causa. Por isso a versão atual
  não tem checklist e a segunda passagem só verifica. O prompt não inclui
  exemplos concretos de refeições para reduzir enviesamento. O match faz-se
  depois, com aliases. Estas correções têm testes com respostas simuladas; a
  precisão da versão atual **ainda não foi medida com fotos reais no dispositivo**.
- iOS: o bridge atual não implementa `describeImage` (só texto via
  `generate`). Nas fotos, o iOS usa sempre o classificador offline.

## Regras de confiança sobre a resposta do modelo — `food_screening.dart`

O mesmo modelo pequeno escreve a lista e depois a confirma, por isso a confirmação
não basta. Estas regras são funções puras, testadas em `test/food_screening_test.dart`
e ligadas em `SystemFoodVision` (ordem: não-alimentos → verificação → coerência de
café). Localização (`where`) e recipiente são **evidência** escrita no diagnóstico,
nunca portões.

1. **Objetos não alimentares são removidos** antes da verificação. Um nome cujas
   palavras (sem artigos) são todas da lista (toalha, guardanapo, copo sozinho,
   chávena sozinha, garrafa, lata, prato, talheres, mesa, papel, menu, recibo,
   tabuleiro, panela, e os equivalentes em inglês) é descartado. "Copo de água"
   fica. Cada nome descartado aparece em "Detalhes da análise" como
   `toalha → dropped (non-food)`.
2. **Nomes genéricos** ("bebida", "comida", "refeição", "sanduíche", "sandes",
   "molho", "carne", "peixe", "fruta", "sobremesa", "drink", "food"...) ficam na
   lista, marcados como `needsChoice`, sem correspondência na base e sem valores
   nutricionais. O cartão pergunta "Que bebida?" (ou equivalente) e abre o seletor
   com esse nome já escrito. "Prato" sozinho é tratado como objeto (ponto 1).
3. **Bebidas tratam-se como alimentos.** Uma bebida (categoria `bebidas` ou palavras
   como água, sumo, cerveja, café) fica na lista principal se a verificação não a
   rejeitar explicitamente. Se o `where` mencionar um recipiente (copo, chávena,
   caneca, garrafa, lata, taça, jarro; ou cup, glass, mug, bottle, can), o
   diagnóstico regista "container in where"; se não, regista "no container in
   where". Não move nada para as sugestões.
4. **Verificação só remove com prova de ausência:**
   - (a) Só `visible: false` apaga um item. Um índice omitido, ou com verdicto não
     booleano, **fica na lista principal como incerto** ("verify omitted, uncertain"),
     com a etiqueta "Hipótese a confirmar" e conta nos totais como os restantes.
   - (b) Um item sem `where` **fica na lista principal** ("no where"). O `where`
     é evidência para o utilizador, não um requisito.
   - Verificação inválida ou ausente mantém a primeira lista inteira ("verify
     unparsed"); as regras 1, 2 e 3 continuam a aplicar-se.
   - Um café duplicado (regra "uma chávena = uma bebida") é a única coisa que
     vai para as sugestões ("duplicate coffee").
   - Verificação que rejeita **todos** os itens não esvazia a lista: todos ficam
     como incertos ("verify rejected all — kept as uncertain"). Com pelo menos um
     item sobrevivente, só os `visible: false` saem. (Antes, rejeitar tudo dava
     refeição vazia confirmada; isso escondia um bife numa frigideira na v0.6.4.)
   - Refeição **confirmada vazia** só quando a 1.ª passagem vem vazia **e** a 2.ª
     tentativa (`buildFoodSecondChancePrompt`) também vem vazia. Uma resposta só com
     objetos não alimentares, ou uma 2.ª resposta inválida, não é confirmada vazia.
     Mesmo assim, as sugestões offline aparecem em "Outras hipóteses" e o ecrã mostra
     o cartão com "Tentar de novo" e a explicação "A IA do telemóvel não encontrou
     comida nesta foto. Tenta outra vez, analisa uma zona ou adiciona manualmente."
   - O filtro de não-alimentos olha **só para o nome** do item. "Bife" com
     `where` "na frigideira" não é removido; "Frigideira" sozinha é.
5. **Falhas explicadas.** `FoodVisionResult.failure` (`VisionFailure`) indica
   `busy` (IA ocupada ou em quota), `unavailable` (não suportada, desligada ou a
   descarregar) ou `other`. A página mostra o motivo em português/inglês e um botão
   "Tentar de novo" que repete a análise da mesma foto. O botão de adicionar
   alimento continua disponível. Com sugestões offline no ecrã, o motivo diz que
   são pouco fiáveis e que devem ser confirmadas ("…Sugestões do reconhecimento
   offline abaixo (pouco fiável) — confirma antes de adicionar.").

**Compromisso desta revisão (recall sobre precisão).** A versão 0.6.3 removia para
sugestões os itens sem `where`, as bebidas sem palavra de recipiente e os itens sem
verdicto. No telemóvel, o modelo pequeno omite com frequência o campo `where` e
escreve locais como "on the table, right"; essas regras apagavam verdadeiros
positivos (cerveja, hambúrguer). Foram retiradas. A precisão passa a depender de:
verificação explícita (`visible: false`), lista de não-alimentos, nomes genéricos
e a regra de um café por chávena. O custo é mais recall e mais falsos positivos
possíveis; o utilizador remove-os na revisão. O diagnóstico em "Detalhes da análise"
mostra a decisão e o motivo de cada item para se poder analisar uma foto concreta.

## Revisão no ecrã — `photo_food_page.dart`

Layout, de cima para baixo (componentes em `widgets/photo_review_widgets.dart`,
modelo puro em `photo/review_model.dart`):

1. **Fila** (só com várias fotos): "Foto 2 de 5".
2. **Foto** arredondada com a etiqueta da origem. Enquanto analisa: véu, faixa de
   leitura suave (parada se o sistema pedir menos movimento) e o passo atual:
   "A identificar alimentos…" e, quando já há rascunho, "A confirmar…".
3. **Uma linha de botões** sob a foto: Zona, 2.º ângulo, Receita, Mais fotos
   (desliza na horizontal em ecrãs estreitos, nunca quebra linha).
4. **Refeição** como fileira horizontal de chips (uma linha, nunca quebra).
5. **Resumo**: kcal grandes e macros. Mostra "parcial" com "Totais sem N por
   escolher." enquanto houver linhas sem valores; "a confirmar" enquanto houver
   rascunho.
6. **Falta algum?** / **Outras hipóteses**: cada uma é uma fileira horizontal
   de chips com título, depois da lista.
7. **Alimentos**: cartões; "Adicionar alimento" e "Esclarecer" fora da lista.
8. **Detalhes da análise (técnico)** no fim, recolhido, com a linha `timing:`.

Cada cartão mostra só o nome e uma linha: "150 g · 267 kcal". Linhas ainda por
escolher mostram "Escolhe o alimento" com um botão "Escolher" e contorno
destacado. Linhas em rascunho mostram "a confirmar…" com indicador. A pílula
"a confirmar" aparece só em itens da IA ainda não confirmados pelo utilizador.
Fonte (USDA/Ciqual/TACO), kcal por 100 g, posição na foto (`where`, texto do
modelo) e "Esclarecer alimento ou porção" ficam em **Detalhes** do cartão. Toda a
linha é tocável para trocar o alimento; o contador de gramas mantém-se.

**Rascunho e final.** A análise usa `analyseProgressive` (ou
`analyseViewsProgressive` para duas fotos da mesma refeição). O rascunho entra
com `pending`; a verificação final **substitui** as linhas: as que continuam
mantêm a identidade e as removidas colapsam com animação. Eventos de uma análise
antiga (página fechada ou outra foto escolhida) são ignorados.

**CTA.** "Adicionar N ao diário" conta só as linhas guardáveis (com alimento e
gramas, sem rascunho). Se houver linhas por escolher, o CTA leva ao primeiro
cartão por escolher e mostra "N por escolher" acima; "Guardar só N" guarda o
resto. Sem nada guardável fica desativado (numa fila, passa a "Seguinte").

**Várias fotos.** Na galeria, a escolha é múltipla (`pickMultiImage`). Com duas
ou mais, pergunta-se "São da mesma refeição?":
- **Refeições diferentes** (predefinido): fila. Cada foto é revista à vez; a
  seguinte começa a ser analisada em segundo plano enquanto revês a atual. Em
  memória há no máximo duas fotos (a atual e a seguinte). "Ignorar" descarta a
  foto; cada foto é libertada ao guardar ou ignorar. Nada é guardado em disco.
- **Mesma refeição**: as duas primeiras fotos são analisadas como dois ângulos
  (`analyseViewsProgressive`). Com mais de duas, avisa-se que só se usam as duas
  primeiras.
A câmara continua a tirar uma foto de cada vez.
- **Região**: o utilizador escolhe um recorte da foto; o recorte é analisado com o
  mesmo pipeline (coordenadas da imagem original) e só entram alimentos da base.
- **Correções**: ao trocar um alimento sugerido pelo sistema ou pelo offline, o
  par (rótulo original → alimento escolhido) fica registado localmente, só
  contagens. Nas escolhas seguintes para o mesmo rótulo, o seletor mostra
  primeiro os alimentos mais escolhidos (até 4). Pode ser desativado ou apagado em
  Nutrição → Receitas habituais → "O que a VYRO sabe sobre ti" (ver `docs/ASSISTANT.md`).
- **Avisos de qualidade** (`photo_quality.dart`): imagem pequena (lado menor
  < 96 px), pouca luz, muita luz ou pouco detalhe (variância global do
  Laplaciano numa amostra de 128 px; heurística, não probabilidade calibrada).
  São só avisos; a análise continua e o utilizador decide. A análise de qualidade
  corre num isolate.
- **Contadores locais** ao guardar: fotos revistas, alimentos/porções corrigidos,
  removidos, adicionados e tempo de revisão. Ficam no dispositivo, sem imagens.
- Sugestões rápidas: ao pequeno-almoço/lanche ou com pão, primeiro manteiga, café,
  galão, doce, fiambre, queijo, sumo (difíceis de ver numa foto).

## Ligar um modelo de deteção/segmentação real

O ideal (ver especificação) é um modelo TFLite de **segmentação de instâncias**
treinado em pratos com vários alimentos. Não existe hoje nenhum com licença e
classes verificadas para incluir. Para o integrar:

1. Colocar `assets/models/<modelo>.tflite` + labels + licença; registar no
   `pubspec.yaml`.
2. Criar `class XFoodVision implements FoodVisionService` em
   `lib/features/nutrition/food_vision/`, confirmando shape/dtype/normalização
   de entrada e o formato das saídas (caixas, máscaras, scores, NMS).
3. Mapear classes → alimentos com `vision_labels` no TSV (ou uma tabela
   própria) e devolver `DetectedFood` com a origem correta.
4. Com máscaras, estimar gramas pela área relativa ao prato × densidade
   típica — sempre como estimativa editável. Sem referência de escala, área 2D
   não dá massa fiável.
5. Integrar via `fuseVisionResults` no `FoodVisionPipeline`, com falhas
   independentes, e acrescentar testes com fotos de amostra
   (`test/food_model_probe_test.dart`). Só mostrar percentagens depois de
   calibrar num conjunto de fotos separado.

## Testar

```bash
flutter test test/food_names_test.dart           # plurais, inglês → base (nome e aliases) → português, genéricos, prompts em inglês, sugestões de acompanhamento
flutter test test/eval_variants_test.dart        # variantes do harness: en_names = prompts da app, pt_prompt histórico
flutter test test/food_progressive_test.dart     # rascunho → final, tempos em detalhes, análise = último evento
flutter test test/food_database_test.dart        # parsing, matching, pipeline (fakes)
flutter test test/vision_resilience_test.dart    # porções por peça, falhas independentes, avisos
flutter test test/system_food_vision_test.dart test/region_food_vision_test.dart
flutter test test/food_screening_test.dart       # não-alimentos, genéricos, bebidas, verificação, falhas, pizza
flutter test test/photo_food_page_test.dart      # cartão de falha, "Tentar de novo", genéricos, refeição vazia confirmada, rascunho → final, CTA e "por escolher", fila de fotos, mesma refeição, falha do sistema com sugestões offline (CTA 0)
flutter test test/food_offline_only_test.dart    # 0.6.8: sem resposta do sistema o offline é só sugestão (Alface); porta de não-alimentos; sucesso do sistema inalterado
flutter test test/photo_review_widgets_test.dart test/photo_review_model_test.dart   # cartão (detalhes, subtítulo), resumo "parcial", fusão de linhas
VYRO_FOOD_IMAGE=C:\fotos\prato.png flutter test test/food_model_probe_test.dart
```

A sonda corre o modelo real no anfitrião (Windows/macOS/Linux) e imprime os
alimentos, gramas e kcal sugeridos. Os restantes testes usam respostas simuladas.

## Limites conhecidos

- Não há medição de precisão, recall ou falsos positivos em fotos reais; a
  avaliação está planeada (`docs/AI_REVIEW_2026-10-25.md`, secção 5). A única
  medição offline é a de `regions_only` (precisão 0,28, recall 0,06, acima).
- O classificador offline reconhece pratos, não ingredientes; pode perder
  alimentos ou sugerir outros. Sem o modelo do sistema, só mostra sugestões.
- A porta de não-alimentos não foi testada com fotos sem comida reais (só
  com respostas simuladas nos testes).
- A segunda passagem do modelo do sistema corre sempre que a primeira devolve
  alimentos; ainda não é condicionada por ambiguidade ou desacordo.
- Recall sobre precisão: a versão atual mantém quase tudo o que o modelo lista.
  Falsos positivos (ex.: uma cerveja que não existe) passam para a revisão e
  têm de ser removidos pelo utilizador. Não há medição com fotos reais; o
  objetivo seguinte é medir os dois erros em um conjunto de fotos, com o
  diagnóstico de cada item.
