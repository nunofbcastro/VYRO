import 'dart:convert';

/// Answers from the plan wizard (version 2). Stored locally so the wizard
/// reopens with the last choices.
///
/// Version 1 stored `goal` as strength/nutrition/routine and `experience` as
/// beginner/intermediate/advanced; [decode] maps both sets, so older
/// preferences keep working.
class PlanPreferences {
  const PlanPreferences({
    this.goal = 'health',
    this.secondaryGoal,
    this.experience = 'under6m',
    this.detraining = 'none',
    this.weekdays = const [1, 3, 5],
    this.sessionMinutes = 45,
    this.location = 'mixed',
    this.equipment = const {'bodyweight', 'dumbbells', 'cable'},
    this.dumbbellMaxKg,
    this.priorities = const {},
    this.limitAreas = const {},
    this.limitations = '',
    this.avoidedExercises = const {},
    this.favouriteExercises = const {},
    this.cardio = 'none',
    this.cardioType = 'walk',
    this.impactAllowed = true,
    this.style = 'traditional',
    this.rest = 'normal',
    this.ageRange,
    this.activityLevel,
    this.blockWeeks = 4,
  });

  /// perder gordura · ganhar músculo · força · resistência · saúde · mobilidade
  final String goal;
  final String? secondaryGoal;

  /// never · under6m · six24m · over2y (legacy: beginner, intermediate,
  /// advanced).
  final String experience;

  /// none · lt1m · 1to6m · gt6m: how long the user has been inactive.
  final String detraining;

  /// ISO weekdays chosen by the user (1 = Monday), sorted.
  final List<int> weekdays;
  final int sessionMinutes;

  /// home · gym · outdoor · mixed
  final String location;
  final Set<String> equipment;

  /// Heaviest dumbbell the user has, in kg. Only meaningful with dumbbells.
  final int? dumbbellMaxKg;

  /// Muscle areas that get extra volume on top of a whole-body week:
  /// legs, glutes, chest, back, shoulders, arms, core. Empty = balanced.
  final Set<String> priorities;

  /// Joint area -> [LimitLevel] key (avoid_impact, avoid_heavy_load,
  /// avoid_completely). See `exercise_traits.dart`.
  final Map<String, String> limitAreas;

  /// Free text ("dor no joelho"). Shown in the plan notes; never sent
  /// anywhere and never used to choose exercises by itself.
  final String limitations;

  final Set<String> avoidedExercises;
  final Set<String> favouriteExercises;

  /// none · finisher · dedicated
  final String cardio;

  /// walk · run · bike · row · hiit
  final String cardioType;

  /// False removes jumps, dynamic lunges and high-impact cardio.
  final bool impactAllowed;

  /// traditional · circuits (supersets of accessories to save time)
  final String style;

  /// short · normal · long
  final String rest;

  /// under18 · 18to39 · 40to59 · 60plus, or null when the user prefers not to
  /// say.
  final String? ageRange;

  /// sedentary · light · active, or null when not given.
  final String? activityLevel;

  /// Length of the training block in weeks (4, 6 or 8). The last week is a
  /// deload week.
  final int blockWeeks;

  int get daysPerWeek => weekdays.length;

  bool get isBlocked => ageRange == 'under18';

  static const goals = [
    'fat_loss',
    'muscle',
    'strength',
    'endurance',
    'health',
    'mobility',
  ];
  static const experiences = ['never', 'under6m', 'six24m', 'over2y'];
  static const detrainingLevels = ['none', 'lt1m', '1to6m', 'gt6m'];
  static const sessionLengths = [20, 30, 45, 60, 75, 90];
  static const locations = ['home', 'gym', 'outdoor', 'mixed'];
  static const equipmentIds = [
    'bodyweight',
    'dumbbells',
    'barbell',
    'rack',
    'bench',
    'bands',
    'kettlebell',
    'pullup_bar',
    'machines',
    'cable',
    'trx',
    'step',
  ];
  static const limitAreaIds = [
    'knee',
    'shoulder',
    'lower_back',
    'wrist_elbow',
    'hip',
    'neck',
    'ankle',
  ];
  static const limitLevels = [
    'avoid_impact',
    'avoid_heavy_load',
    'avoid_completely',
  ];
  static const cardioModes = ['none', 'finisher', 'dedicated'];
  static const cardioTypes = ['walk', 'run', 'bike', 'row', 'hiit'];
  static const styles = ['traditional', 'circuits'];
  static const rests = ['short', 'normal', 'long'];
  static const ageRanges = ['under18', '18to39', '40to59', '60plus'];
  static const activityLevels = ['sedentary', 'light', 'active'];
  static const blockOptions = [4, 6, 8];

  static const allPriorities = [
    'legs',
    'glutes',
    'chest',
    'back',
    'shoulders',
    'arms',
    'core',
  ];

  PlanPreferences copyWith({
    String? goal,
    String? secondaryGoal,
    bool clearSecondaryGoal = false,
    String? experience,
    String? detraining,
    List<int>? weekdays,
    int? sessionMinutes,
    String? location,
    Set<String>? equipment,
    int? dumbbellMaxKg,
    bool clearDumbbellMaxKg = false,
    Set<String>? priorities,
    Map<String, String>? limitAreas,
    String? limitations,
    Set<String>? avoidedExercises,
    Set<String>? favouriteExercises,
    String? cardio,
    String? cardioType,
    bool? impactAllowed,
    String? style,
    String? rest,
    String? ageRange,
    bool clearAgeRange = false,
    String? activityLevel,
    bool clearActivityLevel = false,
    int? blockWeeks,
  }) => PlanPreferences(
    goal: goal ?? this.goal,
    secondaryGoal: clearSecondaryGoal
        ? null
        : (secondaryGoal ?? this.secondaryGoal),
    experience: experience ?? this.experience,
    detraining: detraining ?? this.detraining,
    weekdays: weekdays == null ? this.weekdays : ([...weekdays]..sort()),
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    location: location ?? this.location,
    equipment: equipment ?? this.equipment,
    dumbbellMaxKg: clearDumbbellMaxKg
        ? null
        : (dumbbellMaxKg ?? this.dumbbellMaxKg),
    priorities: priorities ?? this.priorities,
    limitAreas: limitAreas ?? this.limitAreas,
    limitations: limitations ?? this.limitations,
    avoidedExercises: avoidedExercises ?? this.avoidedExercises,
    favouriteExercises: favouriteExercises ?? this.favouriteExercises,
    cardio: cardio ?? this.cardio,
    cardioType: cardioType ?? this.cardioType,
    impactAllowed: impactAllowed ?? this.impactAllowed,
    style: style ?? this.style,
    rest: rest ?? this.rest,
    ageRange: clearAgeRange ? null : (ageRange ?? this.ageRange),
    activityLevel: clearActivityLevel
        ? null
        : (activityLevel ?? this.activityLevel),
    blockWeeks: blockWeeks ?? this.blockWeeks,
  );

  Map<String, Object> toJson() => {
    'version': 2,
    'goal': goal,
    if (secondaryGoal != null) 'secondaryGoal': secondaryGoal!,
    'experience': experience,
    'detraining': detraining,
    'weekdays': weekdays,
    'sessionMinutes': sessionMinutes,
    'location': location,
    'equipment': equipment.toList(),
    if (dumbbellMaxKg != null) 'dumbbellMaxKg': dumbbellMaxKg!,
    'priorities': priorities.toList(),
    'limitAreas': limitAreas,
    'limitations': limitations,
    'avoidedExercises': avoidedExercises.toList(),
    'favouriteExercises': favouriteExercises.toList(),
    'cardio': cardio,
    'cardioType': cardioType,
    'impactAllowed': impactAllowed,
    'style': style,
    'rest': rest,
    if (ageRange != null) 'ageRange': ageRange!,
    if (activityLevel != null) 'activityLevel': activityLevel!,
    'blockWeeks': blockWeeks,
  };

  String encode() => jsonEncode(toJson());

  /// Reads both version 1 and version 2 JSON. Unknown or malformed values
  /// fall back to [fallback] (or the defaults); the function never throws.
  static PlanPreferences decode(String? raw, {PlanPreferences? fallback}) {
    final base = fallback ?? const PlanPreferences();
    if (raw == null || raw.isEmpty) return base;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final days = [
        for (final d in (json['weekdays'] as List? ?? const []))
          if (d is num && d >= 1 && d <= 7) d.toInt(),
      ]..sort();
      final equipment = _set(json['equipment'], equipmentIds);
      final minutes = (json['sessionMinutes'] as num?)?.toInt();
      final maxKg = (json['dumbbellMaxKg'] as num?)?.toInt();
      return PlanPreferences(
        goal: _goal(json['goal'], base.goal),
        secondaryGoal: _goalOrNull(json['secondaryGoal']),
        experience: _experience(json['experience'], base.experience),
        detraining: _oneOf(json['detraining'], detrainingLevels, 'none'),
        weekdays: days.isEmpty ? base.weekdays : days.toSet().toList(),
        sessionMinutes: _nearest(minutes, sessionLengths, base.sessionMinutes),
        location: _oneOf(json['location'], locations, 'mixed'),
        equipment: equipment.isEmpty ? base.equipment : equipment,
        dumbbellMaxKg: maxKg != null && maxKg >= 2 && maxKg <= 100
            ? maxKg
            : null,
        priorities: _set(json['priorities'], allPriorities).isNotEmpty
            ? _set(json['priorities'], allPriorities)
            : _legacyEmphasis(json),
        limitAreas: _limitAreas(json),
        limitations: (json['limitations'] as String? ?? '').trim(),
        avoidedExercises: _set(json['avoidedExercises'], const []),
        favouriteExercises: _set(json['favouriteExercises'], const []),
        cardio: _oneOf(json['cardio'], cardioModes, 'none'),
        cardioType: _oneOf(json['cardioType'], cardioTypes, 'walk'),
        impactAllowed: json['impactAllowed'] is bool
            ? json['impactAllowed'] as bool
            : true,
        style: _oneOf(json['style'], styles, 'traditional'),
        rest: _oneOf(json['rest'], rests, 'normal'),
        ageRange: _oneOfOrNull(json['ageRange'], ageRanges),
        activityLevel: _oneOfOrNull(json['activityLevel'], activityLevels),
        blockWeeks: _nearest(
          (json['blockWeeks'] as num?)?.toInt(),
          blockOptions,
          base.blockWeeks,
        ),
      );
    } catch (_) {
      return base;
    }
  }

  /// Version 0.3.0 stored one "emphasis" value.
  static Set<String> _legacyEmphasis(Map<String, dynamic> json) =>
      switch (json['emphasis']) {
        'legs' => {'legs', 'glutes'},
        'upper' => {'chest', 'back', 'shoulders', 'arms'},
        'core' => {'core'},
        _ => <String>{},
      };

  static Map<String, String> _limitAreas(Map<String, dynamic> json) {
    final raw = json['limitAreas'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (limitAreaIds.contains(entry.key) &&
            entry.value is String &&
            limitLevels.contains(entry.value))
          entry.key as String: entry.value as String,
    };
  }

  static String _goal(Object? value, String fallback) {
    if (value is! String) return fallback;
    return switch (value) {
      'nutrition' => 'fat_loss',
      'routine' => 'health',
      _ => goals.contains(value) ? value : fallback,
    };
  }

  static String? _goalOrNull(Object? value) {
    if (value is! String) return null;
    final goal = _goal(value, '');
    return goal.isEmpty ? null : goal;
  }

  static String _experience(Object? value, String fallback) {
    if (value is! String) return fallback;
    return switch (value) {
      'beginner' => 'under6m',
      'intermediate' => 'six24m',
      'advanced' => 'over2y',
      _ => experiences.contains(value) ? value : fallback,
    };
  }

  static Set<String> _set(Object? raw, List<String> allowed) {
    if (raw is! List) return <String>{};
    return {
      for (final value in raw)
        if (value is String && (allowed.isEmpty || allowed.contains(value)))
          value,
    };
  }

  static String _oneOf(Object? value, List<String> allowed, String fallback) =>
      value is String && allowed.contains(value) ? value : fallback;

  static String? _oneOfOrNull(Object? value, List<String> allowed) =>
      value is String && allowed.contains(value) ? value : null;

  static int _nearest(int? value, List<int> allowed, int fallback) {
    if (value == null) return fallback;
    var best = allowed.first;
    for (final option in allowed) {
      if ((option - value).abs() < (best - value).abs()) best = option;
    }
    return best;
  }
}
