import '../../nutrition/domain/food_product.dart' show dayKey;

/// What a calendar day looks like in the weekly plan.
enum DayStatus {
  /// No workout scheduled and none logged.
  rest,

  /// Scheduled for a future day (or later today).
  planned,

  /// Scheduled for today and not done yet.
  today,

  /// A workout was completed on this date (scheduled or extra).
  done,

  /// The user said they could not train that day.
  skipped,

  /// Scheduled in the past, not done and not skipped.
  missed,
}

/// Minimal view of a plan day for scheduling.
class ScheduleSlot {
  const ScheduleSlot({
    required this.dayId,
    required this.weekday,
    required this.namePt,
    required this.nameEn,
  });

  final int dayId;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int weekday;
  final String namePt;
  final String nameEn;
}

class ScheduledDay {
  const ScheduledDay({
    required this.date,
    required this.status,
    this.slot,
    this.doneWorkout,
  });

  final DateTime date;
  final DayStatus status;

  /// Workout scheduled for this weekday, if any.
  final ScheduleSlot? slot;

  /// Name of the workout logged on this date, if any.
  final String? doneWorkout;

  String get key => dayKey(date);
  bool get isTraining => slot != null;
}

/// Monday of the week containing [day].
DateTime weekStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Seven [ScheduledDay]s (Monday → Sunday) for the week containing [today].
///
/// [done] maps date keys to the name of a workout completed that day;
/// [skipped] holds date keys the user marked as "não posso".
List<ScheduledDay> buildWeek({
  required DateTime today,
  required List<ScheduleSlot> slots,
  required Map<String, String> done,
  required Set<String> skipped,
  DateTime? anchor,
}) {
  final start = weekStart(anchor ?? today);
  final todayKey = dayKey(today);
  final todayDate = DateTime(today.year, today.month, today.day);
  return List.generate(7, (i) {
    final date = DateTime(start.year, start.month, start.day + i);
    final key = dayKey(date);
    ScheduleSlot? slot;
    for (final candidate in slots) {
      if (candidate.weekday == date.weekday) {
        slot = candidate;
        break;
      }
    }
    final DayStatus status;
    if (done.containsKey(key)) {
      status = DayStatus.done;
    } else if (skipped.contains(key)) {
      status = DayStatus.skipped;
    } else if (slot == null) {
      status = DayStatus.rest;
    } else if (key == todayKey) {
      status = DayStatus.today;
    } else if (date.isBefore(todayDate)) {
      status = DayStatus.missed;
    } else {
      status = DayStatus.planned;
    }
    return ScheduledDay(
      date: date,
      status: status,
      slot: slot,
      doneWorkout: done[key],
    );
  });
}

/// Date keys from [today] to Sunday that still have a pending workout —
/// what "esta semana não posso" marks as skipped.
List<String> remainingTrainingKeys(List<ScheduledDay> week) => [
  for (final day in week)
    if (day.status == DayStatus.today || day.status == DayStatus.planned)
      day.key,
];

/// The next workout still to do this week (today first), if any.
ScheduledDay? nextWorkout(List<ScheduledDay> week) {
  for (final day in week) {
    if (day.status == DayStatus.today || day.status == DayStatus.planned) {
      return day;
    }
  }
  return null;
}

/// Why nothing is left this week: all done, paused by the user, or the
/// remaining days simply passed. Null while a workout is still pending.
enum WeekOutcome { allDone, paused, over }

WeekOutcome? weekOutcome(List<ScheduledDay> week, DateTime today) {
  if (nextWorkout(week) != null) return null;
  final progress = weekProgress(week);
  if (progress.scheduled > 0 && progress.done >= progress.scheduled) {
    return WeekOutcome.allDone;
  }
  final todayDate = DateTime(today.year, today.month, today.day);
  final paused = week.any(
    (d) =>
        d.status == DayStatus.skipped &&
        d.isTraining &&
        !d.date.isBefore(todayDate),
  );
  return paused ? WeekOutcome.paused : WeekOutcome.over;
}

/// First scheduled slot of next week (lowest weekday).
ScheduleSlot? firstSlotNextWeek(List<ScheduleSlot> slots) {
  if (slots.isEmpty) return null;
  return ([...slots]..sort((a, b) => a.weekday.compareTo(b.weekday))).first;
}

/// Completed / scheduled counts for the week summary ("2 de 3").
({int done, int scheduled}) weekProgress(List<ScheduledDay> week) => (
  done: week.where((d) => d.status == DayStatus.done).length,
  scheduled: week.where((d) => d.isTraining).length,
);
