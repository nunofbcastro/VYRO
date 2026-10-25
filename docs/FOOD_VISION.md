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
  │       1.ª passagem: só a imagem atual, sem exemplos de pratos →
  │         {items:[{name,count,size}]} com nomes em português
  │       2.ª passagem: a mesma foto revista do zero; a lista corrigida
  │         COMPLETA substitui a anterior se for válida (lista vazia = nada visível)
  │       cada pedido repete-se 1× se o AICore estiver ocupado; o erro e a
  │       resposta crua ficam em "Detalhes da análise"
  │
  ├─ falhas independentes: se um ramo falhar, o outro continua (aviso
  │   "systemFailed"); se os dois falharem, aparece erro de modelo
  │
  ▼ fuseVisionResults: alimentos do sistema primeiro; alimentos do offline que
    coincidem ficam "corroborados"; os restantes são SUGESTÕES fora dos totais
    até o utilizador os aceitar. Uma revisão vazia do sistema não ressuscita
    alimentos do offline.
  │
  ▼ PhotoFoodPage: lista editável (trocar alimento, porção, remover, adicionar,
    sugestões rápidas), totais kcal/P/H/G, refeição, "Adicionar N ao diário"
```

Uma nova fotografia substitui a revisão anterior. A seleção/análise fica
bloqueada durante outro pedido ou gravação; resultados tardios de páginas
fechadas são ignorados.

## Porções e peças — `portion_estimate.dart`

- A única função que calcula gramas é `estimatedGrams`.
- Alimento com `portion_units` no TSV (ex.: 3 sardinhas = 120 g): gramas =
  `portion_g × peças ÷ portion_units × fator`. Três sardinhas dão 120 g, não 360 g.
- Alimento sem `portion_units` (arroz, sopas, pratos): a contagem **não**
  multiplica; só o tamanho aplica.
- Fator de tamanho: pequeno 0,6; médio 1; grande 1,5. Peças limitadas a 1–20.
- Limites finais: 5–1500 g. Alimento não reconhecido: usa um `grams` do modelo
  se existir (limitado), senão 100 g × peças × fator.
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

## IA do sistema — `SystemFoodVision`

- Android: `OnDeviceLlmChannel.describeImage` (Kotlin) →
  `generateContentRequest(ImagePart(jpeg), TextPart(prompt))` com temperatura
  0,1 e uma única resposta candidata. Respostas alternativas nunca se concatenam.
  Requer AICore/Gemini Nano (ex.: Pixel 9+, Galaxy S25+). A imagem é reduzida
  a 768 px e fica só em memória.
- Para a 2.ª foto, o pedido envia as duas imagens e instrui o modelo a reconciliar
  identidades sem somar contagens entre vistas.
- O prompt pede contagens e tamanho relativo (pequeno/médio/grande), não gramas.
  Uma chávena, asa, pires ou reflexo não são tratados como recipientes separados.
  Linhas repetidas do mesmo alimento conservam o maior total, sem somar duplicados.
- Iterações anteriores, testadas num telemóvel real, deram frango ×2, arroz e
  tomate, mas falharam feijão e alface e inventaram laranja. A revisão atual
  pode remover essas sugestões; o prompt não inclui exemplos concretos de
  refeições para reduzir enviesamento. O match faz-se depois, com aliases.
  Estas correções têm testes com respostas simuladas; a precisão da versão
  atual **ainda não foi medida com fotos reais no dispositivo**.
- iOS: o bridge atual não implementa `describeImage` (só texto via
  `generate`). Nas fotos, o iOS usa sempre o classificador offline.

## Revisão no ecrã — `photo_food_page.dart`

- Cada linha mostra o alimento, a porção (gramas, ±), a origem e, se o alimento
  não estiver na base, a indicação de que precisa de escolha.
- "Hipótese a confirmar" marca itens incertos ou vindos do classificador; não há
  percentagens de confiança no ecrã.
- **Segunda foto**: câmara adicional para outro ângulo. O resultado é apresentado
  como candidatos a adicionar; alimentos já revistos são preservados.
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
flutter test test/food_database_test.dart        # parsing, matching, pipeline (fakes)
flutter test test/vision_resilience_test.dart    # porções por peça, falhas independentes, avisos
flutter test test/system_food_vision_test.dart test/region_food_vision_test.dart
flutter test test/photo_food_page_test.dart
VYRO_FOOD_IMAGE=C:\fotos\prato.png flutter test test/food_model_probe_test.dart
```

A sonda corre o modelo real no anfitrião (Windows/macOS/Linux) e imprime os
alimentos, gramas e kcal sugeridos. Os restantes testes usam respostas simuladas.

## Limites conhecidos

- Não há medição de precisão, recall ou falsos positivos em fotos reais; a
  avaliação está planeada (`docs/AI_REVIEW_2026-10-25.md`, secção 5).
- O classificador offline reconhece pratos, não ingredientes; pode perder
  alimentos ou sugerir outros.
- A segunda passagem do modelo do sistema corre sempre que a primeira devolve
  alimentos; ainda não é condicionada por ambiguidade ou desacordo.
