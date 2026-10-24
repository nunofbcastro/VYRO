class LocalFoodReference {
  const LocalFoodReference({
    required this.key,
    required this.namePt,
    required this.nameEn,
    required this.fdcId,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String key, namePt, nameEn;
  final int fdcId;
  final double kcal, protein, carbs, fat;

  String name(bool english) => english ? nameEn : namePt;
  String get provenance => 'USDA FoodData Central · FDC $fdcId · por 100 g';
}

/// Small offline reference of plain foods, not a recipe or dish interpreter.
/// Nutrients describe the specified preparation and should be confirmed by the user.
const localFoodReference = <LocalFoodReference>[
  LocalFoodReference(
    key: 'rice_white_cooked',
    namePt: 'Arroz branco cozido',
    nameEn: 'White rice, cooked',
    fdcId: 168878,
    kcal: 130,
    protein: 2.69,
    carbs: 28.17,
    fat: 0.28,
  ),
  LocalFoodReference(
    key: 'chicken_breast_roasted',
    namePt: 'Peito de frango assado, sem pele',
    nameEn: 'Chicken breast, roasted, skinless',
    fdcId: 171477,
    kcal: 165,
    protein: 31.02,
    carbs: 0,
    fat: 3.57,
  ),
  LocalFoodReference(
    key: 'apple_raw_skin',
    namePt: 'Maçã crua com casca',
    nameEn: 'Apple, raw with skin',
    fdcId: 171688,
    kcal: 52,
    protein: 0.26,
    carbs: 13.81,
    fat: 0.17,
  ),
  LocalFoodReference(
    key: 'banana_raw',
    namePt: 'Banana crua',
    nameEn: 'Banana, raw',
    fdcId: 173944,
    kcal: 89,
    protein: 1.09,
    carbs: 22.84,
    fat: 0.33,
  ),
];
