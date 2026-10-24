# Offline food reference

`lib/features/nutrition/domain/local_food_reference.dart` contains four plain foods for optional manual confirmation in the photo review flow. It is a small starter reference, not a complete nutrient database or recipe recognizer. The user must choose the matching preparation and enter/confirm portion grams; photo class labels do not map to ingredients.

| Food | FDC ID | kcal | Protein (g) | Carbohydrate (g) | Fat (g) per 100 g |
|---|---:|---:|---:|---:|---:|
| White rice, cooked | 168878 | 130 | 2.69 | 28.17 | 0.28 |
| Chicken breast, roasted, skinless | 171477 | 165 | 31.02 | 0 | 3.57 |
| Apple, raw with skin | 171688 | 52 | 0.26 | 13.81 | 0.17 |
| Banana, raw | 173944 | 89 | 1.09 | 22.84 | 0.33 |

Source: U.S. Department of Agriculture, Agricultural Research Service, [FoodData Central](https://fdc.nal.usda.gov/). The USDA states that FoodData Central data is public domain under CC0 and requests source attribution. Rice and chicken values are from SR Legacy FDC records 168878 and 171477. Apple and banana are SR Legacy records 171688 and 173944. Nutrient values vary with food variety, preparation and sample; these references are estimates for the named preparation and are not medical advice.
