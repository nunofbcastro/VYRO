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
  │          1.ª passagem: lista de verificação (proteína, arroz/pão, feijão em molho,
  │             folhas de alface, fruta, bebidas em chávenas, manteiga/doce) → JSON
  │             {items:[{name,count,grams}]} com nomes em português
  │          2.ª passagem: "já listado: …; o que falta?" → mergeDetectedFoods
  │          parseFoodPhotoAnswer: match na base, junta duplicados, gramas 5–1500 g
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

## Fallback offline — `RegionFoodVision`

- Modelo: `assets/models/aiy_food_v1.tflite` (Google AIY Food V1, Apache 2.0,
  entrada 1×192×192×3 uint8, saída 2024 classes uint8, índice 0 = fundo) com
  `aiy_food_v1_labels.csv`.
- É um classificador de **pratos** (uma etiqueta por imagem), não um detetor de
  ingredientes. Por isso classifica 26 recortes e soma as evidências.
- Regras (constantes na classe): etiqueta conta se p ≥ 0,08 (top-5 por região);
  alimento fica se o pico ≥ 0,14 e apareceu em ≥ 2 regiões; no máximo 6;
  apenas um alimento por categoria exclusiva (`carne`, `peixe`, `leguminosas`).
- Gramas = porção típica do alimento (estimativa). Não conta peças.
- Corre num isolate (`Isolate.run`) para não bloquear o ecrã.
- Resultado com o prato de exemplo (arroz, feijão, frango, alface, tomate):
  feijão, alface, tomate, frango e arroz. Noutras fotos pode falhar ou
  sugerir alimentos errados — por isso a revisão é obrigatória.

## IA do sistema — `SystemFoodVision`

- Android: `OnDeviceLlmChannel.describeImage` (Kotlin) →
  `generateContentRequest(ImagePart(jpeg), TextPart(prompt)) { temperature = 0.1f }`.
  Requer AICore/Gemini Nano (ex.: Pixel 9+, Galaxy S25+). A imagem é reduzida
  a 768 px e fica só em memória.
- Conta peças ("2 bifes de frango") e estima gramas com referências de prato.
- Testado num telemóvel real: no prato de exemplo encontrou frango ×2, arroz e
  tomate na 1.ª versão do pedido, mas falhou feijão e alface e inventou
  laranja — daí a lista de verificação e a 2.ª passagem. Sem lista de 131 nomes
  no pedido (enviesava o modelo pequeno); o match faz-se depois, com aliases.
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
VYRO_FOOD_IMAGE=C:\fotos\prato.png flutter test test/food_model_probe_test.dart
```

A sonda corre o modelo real no anfitrião (Windows/macOS/Linux) e imprime os
alimentos, gramas e kcal sugeridos.
