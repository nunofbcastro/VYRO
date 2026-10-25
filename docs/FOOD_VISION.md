# Reconhecimento de alimentos por fotografia

Tudo corre **no telemóvel**: a foto não sai do dispositivo, não há API paga
nem servidor. O reconhecimento só **sugere** alimentos e gramas; os nutrientes
vêm sempre da base offline (`docs/NUTRITION_DATA.md`) e o utilizador confirma
tudo antes de guardar.

## Pipeline

```
foto (câmara/galeria, ficheiro temporário apagado logo após leitura)
  │
  ▼ FoodVisionPipeline (lib/features/nutrition/food_vision/system_food_vision.dart)
  ├─ IA do sistema disponível? (OnDeviceLlm.status() == available)
  │     └─ SystemFoodVision: Gemini Nano multimodal (Android, ML Kit GenAI Prompt API)
  │          1.ª passagem: analisar apenas a imagem atual, sem exemplos de pratos;
  │             lista de grupos alimentares → JSON {items:[{name,count,grams}]}
  │             com nomes em português, contagem e gramas TOTAIS por alimento
  │          2.ª passagem: rever a imagem e devolver a lista COMPLETA corrigida,
  │             removendo alimentos ausentes e corrigindo contagens/omissões
  │          parseFoodPhotoAnswer: match na base, deduplica sem somar porções,
  │             gramas 5–1500 g; resposta vazia válida não ativa o fallback
  │          cada pedido é repetido 1× se o AICore falhar; o erro/resposta crua fica em
  │          FoodVisionResult.detail ("Detalhes da análise" no ecrã)
  │          falha → RegionFoodVision (nota "systemFailed")
  │          iOS (modelo só texto) → MissingPluginException → RegionFoodVision
  └─ caso contrário: RegionFoodVision (offline, qualquer telemóvel)
        classificador AIY Food V1 em 26 regiões (imagem + grelhas 3×3 e 4×4)
        etiquetas → alimentos via vision_labels do TSV
  │
  ▼ PhotoFoodPage: lista editável (trocar alimento, gramas ±, remover, adicionar,
    sugestões rápidas), totais kcal/P/H/G, refeição, "Adicionar N ao diário"
    Sugestões rápidas: ao pequeno-almoço/lanche ou com pão, primeiro manteiga, café,
    galão, doce, fiambre, queijo, sumo (difíceis de ver numa foto).
```

Uma nova fotografia substitui a revisão anterior. A seleção/análise fica
bloqueada durante outro pedido ou gravação; resultados tardios de páginas
fechadas são ignorados. Cancelar a galeria mantém a revisão atual. O diário
guardado nunca é enviado ao modelo como contexto da fotografia seguinte.

## Fallback offline — `RegionFoodVision`

- Modelo: `assets/models/aiy_food_v1.tflite` (Google AIY Food V1, Apache 2.0,
  entrada 1×192×192×3 uint8, saída 2024 classes uint8, índice 0 = fundo) com
  `aiy_food_v1_labels.csv`.
- É um classificador de **pratos** (uma etiqueta por imagem), não um detetor de
  ingredientes. Por isso classifica 26 recortes e soma as evidências.
- Regras (constantes na classe): etiqueta conta se p ≥ 0,08 (top-5 por região);
  alimento fica se o pico ≥ 0,14 e apareceu em ≥ 2 regiões distintas; várias
  etiquetas do mesmo alimento num recorte contam apenas uma vez; no máximo 6;
  apenas um alimento por categoria exclusiva (`carne`, `peixe`, `leguminosas`).
- Gramas = porção típica do alimento (estimativa). Não conta peças.
- Corre num isolate (`Isolate.run`) para não bloquear o ecrã.
- Resultado com o prato de exemplo (arroz, feijão, frango, alface, tomate):
  feijão, alface, tomate, frango e arroz. Noutras fotos pode falhar ou
  sugerir alimentos errados — por isso a revisão é obrigatória.

## IA do sistema — `SystemFoodVision`

- Android: `OnDeviceLlmChannel.describeImage` (Kotlin) →
  `generateContentRequest(ImagePart(jpeg), TextPart(prompt))` com temperatura
  0,1 e uma única resposta candidata. Respostas alternativas nunca se concatenam.
  Requer AICore/Gemini Nano (ex.: Pixel 9+, Galaxy S25+). A imagem é reduzida
  a 768 px e fica só em memória.
- Sugere contagens e gramas; uma chávena, asa, pires ou reflexo não são tratados
  no pedido como recipientes separados. Linhas repetidas do mesmo alimento
  conservam o maior total sugerido, sem somar duplicados. Peças distintas devem
  vir numa única linha com a contagem total explícita.
- Na versão anterior, testada num telemóvel real, o prato de exemplo deu frango ×2, arroz e
  tomate na 1.ª versão do pedido, mas falhou feijão e alface e inventou
  laranja. A revisão atual pode remover essas sugestões; não inclui exemplos
  concretos de refeições no pedido para reduzir enviesamento. O match faz-se
  depois, com aliases. Estas correções têm testes com respostas simuladas;
  a precisão da versão atual ainda requer validação com fotos reais no dispositivo.
- iOS: o Foundation Models atual é só texto → usa o fallback offline.

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
   própria) e devolver `DetectedFood` com `confidence`.
4. Com máscaras, estimar gramas pela área relativa ao prato × densidade
   típica — sempre como estimativa editável.
5. Usá-lo no `FoodVisionPipeline` (antes ou em vez do `RegionFoodVision`) e
   acrescentar testes com fotos de amostra (`test/food_model_probe_test.dart`).

## Testar

```bash
flutter test test/food_database_test.dart        # parsing, matching, pipeline (fakes)
flutter test test/system_food_vision_test.dart test/region_food_vision_test.dart
flutter test test/photo_food_page_test.dart test/brand_splash_test.dart
VYRO_FOOD_IMAGE=C:\fotos\prato.png flutter test test/food_model_probe_test.dart
```

A sonda corre o modelo real no anfitrião (Windows/macOS/Linux) e imprime os
alimentos, gramas e kcal sugeridos.
