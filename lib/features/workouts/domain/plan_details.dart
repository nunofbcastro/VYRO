import 'dart:convert';

import 'plan_generator.dart';
import 'plan_preferences.dart';

/// Where the user is in the training block.
class BlockPosition {
  const BlockPosition({
    required this.week,
    required this.weeks,
    required this.finished,
  });

  /// 1-based week of the block that [today] falls in (clamped to the block).
  final int week;
  final int weeks;

  /// True once the block is over (more than [weeks] weeks after the start).
  final bool finished;

  /// The last week of a block is the deload week.
  bool get deload => !finished && week == weeks;
}

/// Plan facts that are not columns of the plan tables. Stored as JSON in
/// `workout_plans.details` (schema v6), so they survive restarts and travel
/// with the local export.
///
/// Per-exercise progression text is not stored: it is derived from each
/// exercise row (sets, reps, timed) by [progressionRule], so it stays correct
/// after the user edits an exercise.
class PlanDetails {
  const PlanDetails({
    required this.startedOn,
    required this.blockWeeks,
    required this.notes,
    required this.warnings,
    required this.warmups,
    this.summary,
  });

  static const formatVersion = 1;

  /// Local calendar day on which week 1 starts.
  final DateTime startedOn;
  final int blockWeeks;

  /// Deterministic rationale facts ("Porque este plano").
  final List<PlanNote> notes;

  /// Problems the user should fix; empty when there are none.
  final List<PlanNote> warnings;

  /// Warm-up per workout, keyed by the 1-based day number.
  final Map<int, PlanNote> warmups;

  /// The on-device sentence accepted by `parseRationale`, if any.
  final String? summary;

  factory PlanDetails.fromPlan(
    GeneratedPlan plan, {
    required DateTime startedOn,
    String? summary,
  }) {
    final warmups = <int, PlanNote>{};
    for (var i = 0; i < plan.days.length; i++) {
      final day = plan.days[i];
      if (day.warmupPt.isNotEmpty || day.warmupEn.isNotEmpty) {
        warmups[i + 1] = PlanNote(day.warmupPt, day.warmupEn);
      }
    }
    final clean = summary?.trim();
    return PlanDetails(
      startedOn: DateTime(startedOn.year, startedOn.month, startedOn.day),
      blockWeeks: PlanPreferences.blockOptions.contains(plan.blockWeeks)
          ? plan.blockWeeks
          : 4,
      notes: plan.notes,
      warnings: plan.warnings,
      warmups: warmups,
      summary: clean == null || clean.isEmpty ? null : clean,
    );
  }

  /// Position in the block on [today]. Weeks are counted from [startedOn].
  BlockPosition blockPosition(DateTime today) {
    final start = DateTime(startedOn.year, startedOn.month, startedOn.day);
    final now = DateTime(today.year, today.month, today.day);
    final days = now.difference(start).inDays;
    final elapsed = days < 0 ? 0 : days ~/ 7;
    if (elapsed >= blockWeeks) {
      return BlockPosition(week: blockWeeks, weeks: blockWeeks, finished: true);
    }
    return BlockPosition(week: elapsed + 1, weeks: blockWeeks, finished: false);
  }

  String encode() => jsonEncode({
    'version': formatVersion,
    'startedOn': _dateKey(startedOn),
    'blockWeeks': blockWeeks,
    'notes': [for (final note in notes) _noteJson(note)],
    'warnings': [for (final note in warnings) _noteJson(note)],
    'warmups': {
      for (final entry in warmups.entries)
        entry.key.toString(): _noteJson(entry.value),
    },
    if (summary != null) 'summary': summary,
  });

  /// Reads the stored JSON. Returns null when the value is missing or is not
  /// a valid version 1 document; this never throws, so a damaged or imported
  /// row only hides these details.
  static PlanDetails? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['version'] != formatVersion) return null;
      final started = DateTime.tryParse(json['startedOn'] as String? ?? '');
      if (started == null) return null;
      final blockWeeks = json['blockWeeks'];
      if (blockWeeks is! int ||
          !PlanPreferences.blockOptions.contains(blockWeeks)) {
        return null;
      }
      final warmupsJson = json['warmups'];
      final warmups = <int, PlanNote>{};
      if (warmupsJson is Map) {
        for (final entry in warmupsJson.entries) {
          final day = int.tryParse(entry.key.toString());
          final note = _noteFrom(entry.value);
          if (day != null && note != null) warmups[day] = note;
        }
      }
      final summary = json['summary'];
      return PlanDetails(
        startedOn: DateTime(started.year, started.month, started.day),
        blockWeeks: blockWeeks,
        notes: _notesFrom(json['notes']),
        warnings: _notesFrom(json['warnings']),
        warmups: warmups,
        summary: summary is String && summary.trim().isNotEmpty
            ? summary.trim()
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _noteJson(PlanNote note) => {
    'pt': note.pt,
    'en': note.en,
  };

  static PlanNote? _noteFrom(Object? value) {
    if (value is! Map) return null;
    final pt = value['pt'];
    final en = value['en'];
    if (pt is! String || en is! String) return null;
    return PlanNote(pt, en);
  }

  static List<PlanNote> _notesFrom(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (_noteFrom(item) case final note?) note,
    ];
  }

  static String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
