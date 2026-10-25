/// Deterministic, rule-based training plan generator.
///
/// No AI and no hidden heuristics: the split depends only on days per week,
/// the prescription only on goal and experience, and each exercise slot picks
/// the first alternative the user's equipment allows. Every generated plan is
/// an editable starting point, not a medical or professional prescription.
library;

/// One generated workout day.
class PlannedDay {
  const PlannedDay({
    required this.namePt,
    required this.nameEn,
    required this.weekday,
    required this.exercises,
  });

  final String namePt;
  final String nameEn;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int weekday;
  final List<PlannedSlot> exercises;
}

class PlannedSlot {
  const PlannedSlot({
    required this.exerciseKey,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String exerciseKey;
  final int sets;
  final int reps;
  final int restSeconds;
}

class GeneratedPlan {
  const GeneratedPlan({
    required this.titlePt,
    required this.titleEn,
    required this.days,
  });

  final String titlePt;
  final String titleEn;
  final List<PlannedDay> days;
}

/// Sets × reps × rest for a goal and experience level.
class Prescription {
  const Prescription(this.sets, this.reps, this.restSeconds);
  final int sets;
  final int reps;
  final int restSeconds;
}

Prescription prescriptionFor(String goal, String experience) {
  final intermediate = experience == 'intermediate' || experience == 'advanced';
  return switch (goal) {
    'strength' => Prescription(intermediate ? 4 : 3, intermediate ? 6 : 8, 150),
    'nutrition' => Prescription(3, intermediate ? 12 : 15, 60),
    _ => Prescription(3, intermediate ? 8 : 10, 90),
  };
}

/// Spread training days across the week with rest in between where possible.
List<int> defaultWeekdays(int days) => switch (days.clamp(1, 7)) {
  1 => const [3],
  2 => const [1, 4],
  3 => const [1, 3, 5],
  4 => const [1, 2, 4, 5],
  5 => const [1, 2, 3, 5, 6],
  6 => const [1, 2, 3, 4, 5, 6],
  _ => const [1, 2, 3, 4, 5, 6, 7],
};

/// Exercise slot: alternatives in order of preference.
typedef _Slot = List<String>;

const _squat = ['goblet_squat', 'split_squat', 'reverse_lunge'];
const _lunge = ['split_squat', 'reverse_lunge'];
const _hinge = ['hip_hinge', 'glute_bridge'];
const _glute = ['glute_bridge'];
const _push = ['dumbbell_press', 'push_up'];
const _pushAlt = ['push_up', 'dumbbell_press'];
const _overhead = ['shoulder_press', 'pike_push_up'];
const _lateral = ['lateral_raise', 'pike_push_up'];
const _row = ['seated_row', 'dumbbell_row', 'superman'];
const _vertical = ['lat_pulldown', 'dumbbell_row', 'superman'];
const _rearDelt = ['face_pull', 'superman'];
const _biceps = ['biceps_curl'];
const _triceps = ['triceps_pushdown', 'push_up'];
const _calf = ['calf_raise'];
const _core = ['plank', 'dead_bug'];
const _coreAlt = ['dead_bug', 'bird_dog'];
const _coreSide = ['side_plank', 'bird_dog'];

class _DayTemplate {
  const _DayTemplate(this.pt, this.en, this.slots);
  final String pt;
  final String en;
  final List<_Slot> slots;
}

const _fullA = _DayTemplate('Corpo inteiro A', 'Full body A', [
  _squat, _push, _row, _glute, _core, //
]);
const _fullB = _DayTemplate('Corpo inteiro B', 'Full body B', [
  _lunge, _overhead, _vertical, _hinge, _coreAlt, //
]);
const _fullC = _DayTemplate('Corpo inteiro C', 'Full body C', [
  _squat, _pushAlt, _row, _hinge, _coreSide, //
]);
const _upperA = _DayTemplate('Superior A', 'Upper A', [
  _push, _row, _overhead, _vertical, _biceps, _triceps, //
]);
const _upperB = _DayTemplate('Superior B', 'Upper B', [
  _overhead, _vertical, _pushAlt, _row, _rearDelt, _core, //
]);
const _lowerA = _DayTemplate('Inferior A', 'Lower A', [
  _squat, _hinge, _lunge, _calf, _core, //
]);
const _lowerB = _DayTemplate('Inferior B', 'Lower B', [
  _hinge, _lunge, _glute, _calf, _coreSide, //
]);
const _pushDay = _DayTemplate('Empurrar', 'Push', [
  _push, _overhead, _pushAlt, _lateral, _triceps, //
]);
const _pullDay = _DayTemplate('Puxar', 'Pull', [
  _vertical, _row, _rearDelt, _biceps, _coreAlt, //
]);
const _legsDay = _DayTemplate('Pernas', 'Legs', [
  _squat, _hinge, _lunge, _glute, _calf, //
]);
const _mobility = _DayTemplate('Core e mobilidade', 'Core and mobility', [
  _core, _coreAlt, _coreSide, _glute, //
]);

List<_DayTemplate> _split(int days) => switch (days.clamp(1, 7)) {
  1 => const [_fullA],
  2 => const [_fullA, _fullB],
  3 => const [_fullA, _fullB, _fullC],
  4 => const [_upperA, _lowerA, _upperB, _lowerB],
  5 => const [_pushDay, _pullDay, _legsDay, _upperA, _lowerB],
  6 => const [_pushDay, _pullDay, _legsDay, _pushDay, _pullDay, _legsDay],
  _ => const [
    _pushDay,
    _pullDay,
    _legsDay,
    _pushDay,
    _pullDay,
    _legsDay,
    _mobility,
  ],
};

/// Builds a plan.
///
/// [equipmentOf] maps exercise keys to the catalogue equipment description
/// (Portuguese, e.g. "peso corporal ou halteres"); [available] holds the
/// profile choices `bodyweight`, `dumbbells`, `cable`.
GeneratedPlan generatePlan({
  required int daysPerWeek,
  required String goal,
  required String experience,
  required Set<String> available,
  required Map<String, String> equipmentOf,
  List<int>? weekdays,
  int sessionMinutes = 45,
  String emphasis = 'balanced',
}) {
  final days = daysPerWeek.clamp(1, 7);
  final split = _split(days);
  final schedule = weekdays != null && weekdays.length == days
      ? weekdays
      : defaultWeekdays(days);
  final rx = prescriptionFor(goal, experience);

  bool allowed(String key) {
    final needs = equipmentOf[key]?.toLowerCase();
    if (needs == null) return false;
    return (needs.contains('peso corporal') &&
            available.contains('bodyweight')) ||
        (needs.contains('halteres') && available.contains('dumbbells')) ||
        (needs.contains('cabo') && available.contains('cable'));
  }

  final planned = <PlannedDay>[];
  final counts = <String, int>{};
  for (var i = 0; i < days; i++) {
    final template = split[i];
    // Repeated templates (6-7 days) get a "2" suffix.
    final seen = counts.update(template.pt, (v) => v + 1, ifAbsent: () => 1);
    final suffix = seen > 1 ? ' $seen' : '';
    final keys = <String>[];
    void take(_Slot slot) {
      final pick = slot.firstWhere(
        (key) => allowed(key) && !keys.contains(key),
        orElse: () => '',
      );
      if (pick.isNotEmpty) keys.add(pick);
    }

    // Session length decides how many exercises fit; the emphasis gets at
    // least one dedicated slot, then generic accessories fill the rest.
    final target = exercisesForMinutes(sessionMinutes);
    final focus = _emphasisSlots[emphasis] ?? const <_Slot>[];
    final mainSlots = focus.isEmpty ? target : target - 1;
    for (final slot in template.slots) {
      if (keys.length >= mainSlots) break;
      take(slot);
    }
    for (final slot in [...focus, ..._fillerSlots]) {
      if (keys.length >= target) break;
      take(slot);
    }
    if (keys.isEmpty) keys.addAll(['plank', 'dead_bug', 'glute_bridge']);
    planned.add(
      PlannedDay(
        namePt: '${template.pt}$suffix',
        nameEn: '${template.en}$suffix',
        weekday: schedule[i],
        exercises: [
          for (final key in keys)
            PlannedSlot(
              exerciseKey: key,
              // Core and isolation work stays at 3 sets.
              sets: _isAccessory(key) ? 3 : rx.sets,
              reps: _isAccessory(key) ? 12 : rx.reps,
              restSeconds: _isAccessory(key) ? 60 : rx.restSeconds,
            ),
        ],
      ),
    );
  }

  final goalPt = switch (goal) {
    'strength' => 'Força',
    'nutrition' => 'Composição corporal',
    _ => 'Rotina',
  };
  final goalEn = switch (goal) {
    'strength' => 'Strength',
    'nutrition' => 'Body composition',
    _ => 'Routine',
  };
  return GeneratedPlan(
    titlePt: '$goalPt · $days dias',
    titleEn: '$goalEn · $days days',
    days: planned,
  );
}

/// Exercises per session for a target duration (warm-up included).
int exercisesForMinutes(int minutes) => switch (minutes) {
  <= 30 => 4,
  <= 45 => 5,
  <= 60 => 6,
  _ => 7,
};

/// Rough session length: work (≈3 s per rep) plus rest between sets, plus a
/// 5-minute warm-up. Shown as guidance, not a precise timer.
int estimateMinutes(Iterable<PlannedSlot> slots) {
  var seconds = 300;
  for (final slot in slots) {
    seconds += slot.sets * (slot.reps * 3 + slot.restSeconds);
  }
  return (seconds / 60).round();
}

const _emphasisSlots = <String, List<_Slot>>{
  'legs': [_lunge, _glute, _calf],
  'upper': [_lateral, _biceps, _triceps, _rearDelt],
  'core': [_core, _coreAlt, _coreSide],
};

const _fillerSlots = <_Slot>[
  _core,
  _glute,
  _calf,
  _lateral,
  _biceps,
  _triceps,
  _coreSide,
  _rearDelt,
];

const _accessories = {
  'plank',
  'dead_bug',
  'side_plank',
  'bird_dog',
  'lateral_raise',
  'biceps_curl',
  'triceps_pushdown',
  'face_pull',
  'calf_raise',
  'superman',
};

bool _isAccessory(String key) => _accessories.contains(key);

/// Short weekday name (Seg / Mon).
String weekdayShort(int weekday, {required bool english}) {
  const pt = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return (english ? en : pt)[(weekday - 1).clamp(0, 6)];
}

/// Full weekday name (Segunda-feira / Monday).
String weekdayLong(int weekday, {required bool english}) {
  const pt = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const en = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return (english ? en : pt)[(weekday - 1).clamp(0, 6)];
}
