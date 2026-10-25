import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../exercise_analysis/exercise_analysis_engine.dart';

/// Stores camera-analysed sets locally (numbers and events only — never
/// video or images).
class MotionHistoryRepository {
  MotionHistoryRepository(this.database);
  final AppDatabase database;

  Future<int> save({
    required String exerciseKey,
    required DateTime startedAt,
    required SetSummary summary,
  }) => database
      .into(database.motionAnalyses)
      .insert(
        MotionAnalysesCompanion.insert(
          exerciseKey: exerciseKey,
          patternId: summary.patternId,
          startedAt: startedAt,
          durationMs: summary.duration.inMilliseconds,
          fullReps: summary.fullReps,
          partialReps: summary.partialReps,
          holdMs: Value(summary.holdTime.inMilliseconds),
          meanConfidence: summary.meanConfidence,
          observedRatio: summary.observedRatio,
          status: summary.status.name,
          eventsJson: Value(
            jsonEncode([for (final e in summary.events) e.toJson()]),
          ),
          techniqueScore: Value(summary.techniqueScore),
        ),
      );

  /// Newest first, optionally for one exercise.
  Stream<List<MotionAnalysisRecord>> watch({
    String? exerciseKey,
    int limit = 20,
  }) {
    final query = database.select(database.motionAnalyses)
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
      ..limit(limit);
    if (exerciseKey != null) {
      query.where((row) => row.exerciseKey.equals(exerciseKey));
    }
    return query.watch();
  }

  Future<void> delete(int id) => (database.delete(
    database.motionAnalyses,
  )..where((row) => row.id.equals(id))).go();

  /// Event check ids of a stored set.
  static List<String> eventIds(MotionAnalysisRecord record) {
    try {
      return [
        for (final e in jsonDecode(record.eventsJson) as List)
          if (e is Map && e['checkId'] is String) e['checkId'] as String,
      ];
    } catch (_) {
      return const [];
    }
  }
}
