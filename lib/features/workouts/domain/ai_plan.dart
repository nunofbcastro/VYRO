import 'dart:convert';

import 'plan_generator.dart';
import 'plan_preferences.dart';

/// Catalogue entry the AI may choose from.
class CatalogChoice {
  const CatalogChoice({
    required this.key,
    required this.name,
    required this.muscleGroup,
  });

  final String key;
  final String name;
  final String muscleGroup;
}

/// Prompt asking the on-device model for a plan as strict JSON, restricted to
/// [allowed] exercises (already filtered by the user's equipment).
String buildPlanPrompt(
  PlanPreferences prefs,
  List<CatalogChoice> allowed, {
  required bool english,
}) {
  final goal = switch (prefs.goal) {
    'strength' => english ? 'get stronger' : 'ganhar força',
    'nutrition' =>
      english
          ? 'body composition / fat loss'
          : 'composição corporal / perder gordura',
    _ => english ? 'healthy routine' : 'rotina saudável',
  };
  final priorityNames = {
    'legs': english ? 'legs' : 'pernas',
    'glutes': english ? 'glutes' : 'glúteos',
    'chest': english ? 'chest' : 'peito',
    'back': english ? 'back' : 'costas',
    'shoulders': english ? 'shoulders' : 'ombros',
    'arms': english ? 'arms' : 'braços',
    'core': 'core',
  };
  final priorities = prefs.priorities.isEmpty
      ? 'none (balanced)'
      : prefs.priorities.map((p) => priorityNames[p] ?? p).join(', ');
  final days = prefs.weekdays
      .map((d) => weekdayLong(d, english: english))
      .join(', ');
  final catalog = allowed
      .map((c) => '${c.key} (${c.name}, ${c.muscleGroup})')
      .join('; ');
  final count = exercisesForMinutes(prefs.sessionMinutes);
  final language = english ? 'English' : 'Portuguese (Portugal)';
  return '''
You design gym workout plans. Reply with JSON only, no markdown, no comments.
Goal: $goal. Experience: ${prefs.experience}.
Priority areas (EXTRA volume only, never exclusive): $priorities.
Training days (${prefs.daysPerWeek}): $days. Session length: ${prefs.sessionMinutes} minutes, so $count exercises per day.
${prefs.limitations.isEmpty ? '' : 'Limitations to respect (avoid exercises that stress them): ${prefs.limitations}.\n'}Use ONLY these exercise keys: $catalog.
Train the WHOLE body every week: legs, chest, back, shoulders and core must all appear. Priority areas get about one extra exercise per session; they must not replace the other groups. Do not repeat an exercise within a day, put compound exercises first.
Write day names in $language (short, like "Pernas e glúteos").
Format:
{"days":[{"name":"...","exercises":[{"key":"goblet_squat","sets":3,"reps":10}]}],"notes":"one short sentence in $language"}
The "days" array must have exactly ${prefs.daysPerWeek} items.''';
}

class AiPlanResult {
  const AiPlanResult({required this.plan, this.notes});
  final GeneratedPlan plan;
  final String? notes;
}

/// Parses and validates the model's JSON. Returns null when it cannot be
/// trusted, so the caller falls back to the rule-based generator.
///
/// Validation: right number of days; only allowed catalogue keys; no
/// duplicates in a day; 3–8 exercises per day; sets 2–5 and reps 5–20
/// clamped; rest set by goal (not by the model).
AiPlanResult? parseAiPlan(
  String raw, {
  required PlanPreferences prefs,
  required Set<String> allowedKeys,
  required GeneratedPlan fallbackTitles,
  Map<String, String> muscleGroupOf = const {},
}) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  Map<String, dynamic> json;
  try {
    json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final rawDays = json['days'];
  if (rawDays is! List || rawDays.length != prefs.daysPerWeek) return null;

  final rx = prescriptionFor(prefs.goal, prefs.experience);
  final maxPerDay = exercisesForMinutes(prefs.sessionMinutes) + 1;
  final days = <PlannedDay>[];
  for (var i = 0; i < rawDays.length; i++) {
    final day = rawDays[i];
    if (day is! Map) return null;
    final name = (day['name'] as String? ?? '').trim();
    final exercises = day['exercises'];
    if (exercises is! List) return null;
    final slots = <PlannedSlot>[];
    final seen = <String>{};
    for (final e in exercises) {
      if (e is! Map) continue;
      final key = e['key'];
      if (key is! String || !allowedKeys.contains(key) || !seen.add(key)) {
        continue;
      }
      final sets = ((e['sets'] as num?)?.round() ?? rx.sets).clamp(2, 5);
      final reps = ((e['reps'] as num?)?.round() ?? rx.reps).clamp(5, 20);
      slots.add(
        PlannedSlot(
          exerciseKey: key,
          sets: sets,
          reps: reps,
          restSeconds: rx.restSeconds,
        ),
      );
      if (slots.length >= maxPerDay) break;
    }
    if (slots.length < 3) return null;
    final fallback = fallbackTitles.days[i];
    final safeName = name.isEmpty || name.length > 40 ? null : name;
    days.add(
      PlannedDay(
        namePt: safeName ?? fallback.namePt,
        nameEn: safeName ?? fallback.nameEn,
        weekday: prefs.weekdays[i],
        exercises: slots,
      ),
    );
  }
  // A plan that drops a major area (e.g. only "priority" days) is rejected
  // so the balanced rule-based plan is used instead.
  if (muscleGroupOf.isNotEmpty) {
    final covered = {
      for (final day in days)
        for (final slot in day.exercises) muscleGroupOf[slot.exerciseKey],
    };
    const required = [
      {'legs', 'glutes', 'hamstrings'},
      {'chest', 'shoulders'},
      {'back'},
    ];
    for (final group in required) {
      if (covered.intersection(group).isEmpty) return null;
    }
  }
  final notes = (json['notes'] as String?)?.trim();
  return AiPlanResult(
    plan: GeneratedPlan(
      titlePt: fallbackTitles.titlePt,
      titleEn: fallbackTitles.titleEn,
      days: days,
    ),
    notes: notes == null || notes.isEmpty || notes.length > 300 ? null : notes,
  );
}
