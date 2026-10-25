import 'dart:convert';

/// Answers from the plan wizard. Stored locally so the wizard reopens with
/// the last choices.
class PlanPreferences {
  const PlanPreferences({
    this.goal = 'routine',
    this.experience = 'beginner',
    this.weekdays = const [1, 3, 5],
    this.sessionMinutes = 45,
    this.equipment = const {'bodyweight', 'dumbbells', 'cable'},
    this.priorities = const {},
    this.limitations = '',
  });

  final String goal;
  final String experience;

  /// ISO weekdays chosen by the user (1 = Monday), sorted.
  final List<int> weekdays;
  final int sessionMinutes;
  final Set<String> equipment;

  /// Muscle areas that get extra volume on top of a full-body week:
  /// legs, glutes, chest, back, shoulders, arms, core. Empty = balanced.
  final Set<String> priorities;

  static const allPriorities = [
    'legs',
    'glutes',
    'chest',
    'back',
    'shoulders',
    'arms',
    'core',
  ];

  /// Free text ("dor no joelho"), only used to tell the AI what to avoid.
  final String limitations;

  int get daysPerWeek => weekdays.length;

  PlanPreferences copyWith({
    String? goal,
    String? experience,
    List<int>? weekdays,
    int? sessionMinutes,
    Set<String>? equipment,
    Set<String>? priorities,
    String? limitations,
  }) => PlanPreferences(
    goal: goal ?? this.goal,
    experience: experience ?? this.experience,
    weekdays: weekdays == null ? this.weekdays : ([...weekdays]..sort()),
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    equipment: equipment ?? this.equipment,
    priorities: priorities ?? this.priorities,
    limitations: limitations ?? this.limitations,
  );

  Map<String, Object> toJson() => {
    'goal': goal,
    'experience': experience,
    'weekdays': weekdays,
    'sessionMinutes': sessionMinutes,
    'equipment': equipment.toList(),
    'priorities': priorities.toList(),
    'limitations': limitations,
  };

  String encode() => jsonEncode(toJson());

  static PlanPreferences decode(String? raw, {PlanPreferences? fallback}) {
    final base = fallback ?? const PlanPreferences();
    if (raw == null || raw.isEmpty) return base;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final days = [
        for (final d in (json['weekdays'] as List? ?? const []))
          if (d is num && d >= 1 && d <= 7) d.toInt(),
      ]..sort();
      final equipment = {
        for (final e in (json['equipment'] as List? ?? const []))
          if (e is String &&
              const {'bodyweight', 'dumbbells', 'cable'}.contains(e))
            e,
      };
      final minutes = (json['sessionMinutes'] as num?)?.toInt() ?? 45;
      return PlanPreferences(
        goal: _oneOf(json['goal'], const {
          'strength',
          'nutrition',
          'routine',
        }, base.goal),
        experience: _oneOf(json['experience'], const {
          'beginner',
          'intermediate',
          'advanced',
        }, base.experience),
        weekdays: days.isEmpty ? base.weekdays : days.toSet().toList(),
        sessionMinutes: minutes.clamp(20, 120),
        equipment: equipment.isEmpty ? base.equipment : equipment,
        priorities: _priorities(json),
        limitations: (json['limitations'] as String? ?? '').trim(),
      );
    } catch (_) {
      return base;
    }
  }

  static Set<String> _priorities(Map<String, dynamic> json) {
    final raw = json['priorities'];
    if (raw is List) {
      return {
        for (final p in raw)
          if (p is String && allPriorities.contains(p)) p,
      };
    }
    // Version 0.3.0 stored one "emphasis" value.
    return switch (json['emphasis']) {
      'legs' => {'legs', 'glutes'},
      'upper' => {'chest', 'back', 'shoulders', 'arms'},
      'core' => {'core'},
      _ => <String>{},
    };
  }

  static String _oneOf(Object? value, Set<String> allowed, String fallback) =>
      value is String && allowed.contains(value) ? value : fallback;
}
