import 'package:flutter/widgets.dart';

import '../core/ai/on_device_llm.dart';
import '../core/ai/local_intelligence_repository.dart';
import '../core/database/app_database.dart';
import '../features/nutrition/data/nutrition_repository.dart';
import '../features/nutrition/data/open_food_facts_repository.dart';
import '../features/workouts/data/workout_repository.dart';

class AppServices {
  AppServices({
    AppDatabase? database,
    NutritionRepository? nutritionRepository,
    ProductLookupRepository? productLookupRepository,
    OnDeviceLlm? llm,
  }) : database = database ?? AppDatabase(),
       llm = llm ?? const PlatformOnDeviceLlm() {
    this.nutritionRepository =
        nutritionRepository ?? DriftNutritionRepository(this.database);
    this.productLookupRepository =
        productLookupRepository ?? OpenFoodFactsRepository(this.database);
    workoutRepository = WorkoutRepository(this.database);
    localIntelligence = LocalIntelligenceRepository(this.database);
  }

  final AppDatabase database;

  /// OS-provided language model (Apple Intelligence / Gemini Nano).
  final OnDeviceLlm llm;
  late final NutritionRepository nutritionRepository;
  late final ProductLookupRepository productLookupRepository;
  late final WorkoutRepository workoutRepository;
  late final LocalIntelligenceRepository localIntelligence;
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServicesScope>()!.services;

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      !identical(services, oldWidget.services);
}
