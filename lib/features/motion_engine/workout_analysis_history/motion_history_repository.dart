import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../exercise_analysis/exercise_analysis_engine.dart';

/// Stores camera-analysed sets locally (numbers and events only — never
/// video or images).
class MotionHistoryRepository {
  MotionHistoryRepository(this.database);
  final AppDatabase database;

  static String describe(
    MotionAnalysisRecord r, {
    required String name,
    bool english = false,
  }) {
    final inconclusive = r.observedRatio < 0.6 || r.status == 'inconclusive';
    final prefix = english ? 'Observed locally' : 'Observado no dispositivo';
    return '$prefix: $name · ${r.fullReps} ${english ? "full reps" : "repetições completas"} · ${r.partialReps} ${english ? "partial" : "parciais"} · ${(r.durationMs / 1000).round()} s. '
        '${english ? "Observed samples" : "Amostras observadas"}: ${(r.observedRatio * 100).round()}%. '
        '${inconclusive ? (english ? "Observation insufficient for conclusions." : "Observação insuficiente para conclusões.") : (english ? "${eventIds(r).length} provisional technique events." : "${eventIds(r).length} eventos provisórios de movimento.")} '
        '${english ? "This is not a technique or safety certification." : "Não é uma certificação de técnica ou segurança."}';
  }

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

  Future<void> correctCounts(
    int id, {
    required int full,
    required int partial,
    int? originalFull,
    int? originalPartial,
  }) => database.transaction(() async {
    if (full < 0 || partial < 0 || full > 1000 || partial > 1000)
      throw const FormatException('Invalid counts');
    final row = await (database.select(
      database.motionAnalyses,
    )..where((r) => r.id.equals(id))).getSingle();
    final events = (jsonDecode(row.eventsJson) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final prior = events.where((e) => e['type'] == 'user_count_correction');
    final detectedFull = prior.isEmpty
        ? (originalFull ?? row.fullReps)
        : prior.first['detectedFull'];
    final detectedPartial = prior.isEmpty
        ? (originalPartial ?? row.partialReps)
        : prior.first['detectedPartial'];
    events.removeWhere((e) => e['type'] == 'user_count_correction');
    events.add({
      'type': 'user_count_correction',
      'detectedFull': detectedFull,
      'detectedPartial': detectedPartial,
      'confirmedFull': full,
      'confirmedPartial': partial,
    });
    await (database.update(
      database.motionAnalyses,
    )..where((r) => r.id.equals(id))).write(
      MotionAnalysesCompanion(
        fullReps: Value(full),
        partialReps: Value(partial),
        techniqueScore: const Value(null),
        eventsJson: Value(jsonEncode(events)),
      ),
    );
  });

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
