import 'package:flutter/widgets.dart';

import '../core/database/app_database.dart';
import '../features/nutrition/data/nutrition_repository.dart';
import '../features/nutrition/data/open_food_facts_repository.dart';
import '../features/workouts/data/workout_repository.dart';

class AppServices {
  AppServices({
    AppDatabase? database,
    NutritionRepository? nutritionRepository,
    ProductLookupRepository? productLookupRepository,
  }) : database = database ?? AppDatabase() {
    this.nutritionRepository =
        nutritionRepository ?? DriftNutritionRepository(this.database);
    this.productLookupRepository =
        productLookupRepository ?? OpenFoodFactsRepository(this.database);
    workoutRepository = WorkoutRepository(this.database);
  }

  final AppDatabase database;
  late final NutritionRepository nutritionRepository;
  late final ProductLookupRepository productLookupRepository;
  late final WorkoutRepository workoutRepository;
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
