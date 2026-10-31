/// Deterministic, rule-based training plan generator.
///
/// No AI picks sets, reps or exercises. Every decision is a rule that can be
/// read in `docs/WORKOUT_PLANS.md`:
///   1. split: days per week and experience (`_splitFor`);
///   2. exercises: each template slot takes the first alternative that the
///      equipment, avoided list, joint limitations, impact and age rules
///      allow (`exercise_traits.dart`);
///   3. prescription: goal × experience × detraining × rest preference;
///   4. time: estimated minutes are fitted to the session length by trimming
///      accessories, then pairing them into supersets when asked;
///   5. block: weeks of progression and a final deload week.
///
/// The on-device model may only rephrase [GeneratedPlan.notes]; it never
/// changes this output. Every plan is an editable starting point, not a
/// medical or professional prescription.
library;

import 'dart:math' show max;

import '../../../app/l10n/strings.dart';
import 'exercise_traits.dart';
import 'plan_preferences.dart';

/// Plain-language fact about a generated plan, in both languages.
class PlanNote {
  const PlanNote(this.pt, this.en);
  final String pt;
  final String en;
  String text(bool english) => english ? en : pt;
}

/// A note about one training day. [pt] and [en] are the text without the day
/// label, which [groupDayNotes] adds.
class DayNote {
  const DayNote({required this.day, required this.pt, required this.en});
  final int day;
  final String pt;
  final String en;
}

/// Day label for [days]: "Dia 2", "Dias 1–3", "Dias 1, 3 e 5" (EN: "Day 2",
/// "Days 1–3", "Days 1, 3 and 5").
String _dayLabel(List<int> days, {required bool english}) {
  final sorted = [...days]..sort();
  if (sorted.length == 1) return '${english ? 'Day' : 'Dia'} ${sorted.single}';
  final plural = english ? 'Days' : 'Dias';
  final consecutive = [
    for (var i = 1; i < sorted.length; i++) sorted[i] - sorted[i - 1] == 1,
  ].every((step) => step);
  if (consecutive) return '$plural ${sorted.first}–${sorted.last}';
  final head = sorted.sublist(0, sorted.length - 1).join(', ');
  return '$plural $head ${english ? 'and' : 'e'} ${sorted.last}';
}

/// Turns per-day notes into plan notes. Days whose text is identical (in both
/// languages) share one line, in first-seen order; different texts stay apart.
List<PlanNote> groupDayNotes(Iterable<DayNote> notes) {
  final groups = <(String, String), List<int>>{};
  for (final note in notes) {
    groups.putIfAbsent((note.pt, note.en), () => []).add(note.day);
  }
  return [
    for (final entry in groups.entries)
      PlanNote(
        '${_dayLabel(entry.value, english: false)}: ${entry.key.$1}',
        '${_dayLabel(entry.value, english: true)}: ${entry.key.$2}',
      ),
  ];
}

/// One generated workout day.
class PlannedDay {
  const PlannedDay({
    required this.namePt,
    required this.nameEn,
    required this.weekday,
    required this.exercises,
    this.cardioMinutes = 0,
    this.cardioType,
    this.estimatedMinutes = 0,
    this.warmupPt = '',
    this.warmupEn = '',
  });

  final String namePt;
  final String nameEn;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int weekday;
  final List<PlannedSlot> exercises;

  /// Finisher cardio appended to the session, 0 for none.
  final int cardioMinutes;

  /// walk · run · bike · row · hiit, when [cardioMinutes] > 0.
  final String? cardioType;

  /// Warm-up 5 min + work + rest + cardio, as the generator estimated it.
  final int estimatedMinutes;

  /// Day-relevant 5-minute warm-up.
  final String warmupPt;
  final String warmupEn;
}

class PlannedSlot {
  const PlannedSlot({
    required this.exerciseKey,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.supersetGroup,
  });

  final String exerciseKey;
  final int sets;

  /// Top of the rep range (or seconds for timed exercises).
  final int reps;
  final int restSeconds;

  /// Slots with the same non-null group are done as a superset.
  final int? supersetGroup;

  bool get timed => exerciseTraits[exerciseKey]?.timed ?? false;
}

class GeneratedPlan {
  const GeneratedPlan({
    required this.titlePt,
    required this.titleEn,
    required this.days,
    this.blockWeeks = 4,
    this.weeks = const [],
    this.notes = const [],
    this.warnings = const [],
  });

  final String titlePt;
  final String titleEn;
  final List<PlannedDay> days;
  final int blockWeeks;
  final List<BlockWeek> weeks;
  final List<PlanNote> notes;

  /// Problems the user should fix (for example, a day with too few exercises
  /// for the equipment and limitations chosen). Empty when there are none.
  final List<PlanNote> warnings;
}

/// One week of the training block. [pt] and [en] are the body text only.
class BlockWeek {
  const BlockWeek({
    required this.number,
    required this.deload,
    required this.pt,
    required this.en,
  });

  final int number;
  final bool deload;
  final String pt;
  final String en;

  /// Share of the normal number of sets. The deload week is about 40% lower.
  double get volumeFactor => deload ? 0.6 : 1.0;
}

/// Sets × reps × rest for a goal and experience level.
class Prescription {
  const Prescription(this.sets, this.reps, this.restSeconds, {this.repMin});
  final int sets;

  /// Top of the rep range.
  final int reps;
  final int restSeconds;
  final int? repMin;
}

/// Level used by the prescription table: beginner, intermediate or advanced.
/// Accepts both version 1 values and version 2 experience values.
String levelOf(String experience) => switch (experience) {
  'intermediate' || 'six24m' => 'intermediate',
  'advanced' || 'over2y' => 'advanced',
  _ => 'beginner',
};

/// Goal key. Accepts the version 1 goals (strength, nutrition, routine).
String goalKeyOf(String goal) => switch (goal) {
  'nutrition' => 'fat_loss',
  'routine' => 'health',
  _ => PlanPreferences.goals.contains(goal) ? goal : 'health',
};

/// Sets × reps × rest for a goal and experience (version 1 signature kept).
Prescription prescriptionFor(
  String goal,
  String experience, {
  String detraining = 'none',
  String rest = 'normal',
}) {
  final level = levelOf(experience);
  final index = switch (level) {
    'intermediate' => 1,
    'advanced' => 2,
    _ => 0,
  };
  // sets, top reps, bottom reps, rest seconds, per level (beginner, mid, adv).
  final (sets, reps, repMin, restBase) = switch (goalKeyOf(goal)) {
    'strength' => (
      const [3, 4, 5][index],
      const [8, 6, 5][index],
      const [6, 4, 3][index],
      const [120, 150, 180][index],
    ),
    'muscle' => (const [3, 4, 4][index], 12, 8, const [75, 90, 90][index]),
    'fat_loss' => (3, 15, 12, 60),
    'endurance' => (const [2, 3, 3][index], 20, 15, 45),
    'mobility' => (2, 12, 10, 45),
    _ => (3, const [10, 12, 12][index], 10, const [75, 90, 90][index]),
  };
  final cut = detraining == '1to6m' || detraining == 'gt6m';
  final adjustedSets = cut ? (sets - 1).clamp(2, sets) : sets;
  return Prescription(
    adjustedSets,
    reps,
    _restFor(restBase, rest),
    repMin: repMin,
  );
}

/// The one formatter for rep ranges and rep counts (rationale, cards and
/// progression text). A degenerate range (bottom == top, or no bottom) reads as
/// a single number: "10 repetições" / "10 reps", never "10–10".
String repRangeText({required int top, int? bottom, required bool english}) {
  final range = bottom == null || bottom >= top ? '$top' : '$bottom–$top';
  return english ? '$range reps' : '$range repetições';
}

int _restFor(int seconds, String preference) {
  final factor = switch (preference) {
    'short' => 0.75,
    'long' => 1.3,
    _ => 1.0,
  };
  return ((seconds * factor) / 15).round() * 15;
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

const _squat = [
  'goblet_squat',
  'kettlebell_squat',
  'box_squat',
  'leg_press',
  'barbell_squat',
  'split_squat',
];
const _lunge = ['split_squat', 'step_up', 'reverse_lunge', 'leg_press'];
const _hinge = ['hip_hinge', 'hip_thrust', 'glute_bridge'];
const _glute = ['glute_bridge', 'hip_thrust'];
const _push = ['dumbbell_press', 'bench_press', 'push_up'];
const _pushAlt = ['push_up', 'dumbbell_press', 'bench_press', 'landmine_press'];
const _overhead = ['shoulder_press', 'landmine_press', 'pike_push_up'];
const _lateral = ['lateral_raise', 'face_pull', 'pike_push_up'];
const _row = ['seated_row', 'dumbbell_row', 'trx_row', 'superman'];
const _vertical = ['lat_pulldown', 'pull_up', 'dumbbell_row', 'superman'];
const _rearDelt = ['face_pull', 'band_pull_apart', 'superman'];
const _biceps = ['biceps_curl'];
const _triceps = ['triceps_pushdown', 'push_up'];
const _calf = ['calf_raise'];
const _core = ['plank', 'dead_bug'];
const _coreAlt = ['dead_bug', 'bird_dog'];
const _coreSide = ['side_plank', 'bird_dog'];
const _balance = ['single_leg_balance'];
const _balanceKey = 'single_leg_balance';

class _DayTemplate {
  const _DayTemplate(this.pt, this.en, this.focus, this.slots);
  final String pt;
  final String en;

  /// full · upper · lower · push · pull · legs · mobility (warm-up text).
  final String focus;
  final List<_Slot> slots;
}

const _fullA = _DayTemplate('Corpo inteiro A', 'Full body A', 'full', [
  _squat, _push, _row, _glute, _core, //
]);
const _fullB = _DayTemplate('Corpo inteiro B', 'Full body B', 'full', [
  _lunge, _overhead, _vertical, _hinge, _coreAlt, //
]);
const _fullC = _DayTemplate('Corpo inteiro C', 'Full body C', 'full', [
  _squat, _pushAlt, _row, _hinge, _coreSide, //
]);
const _upperA = _DayTemplate('Superior A', 'Upper A', 'upper', [
  _push, _row, _overhead, _vertical, _biceps, _triceps, //
]);
const _upperB = _DayTemplate('Superior B', 'Upper B', 'upper', [
  _overhead, _vertical, _pushAlt, _row, _rearDelt, _core, //
]);
const _lowerA = _DayTemplate('Inferior A', 'Lower A', 'lower', [
  _squat, _hinge, _lunge, _calf, _core, //
]);
const _lowerB = _DayTemplate('Inferior B', 'Lower B', 'lower', [
  _hinge, _lunge, _glute, _calf, _coreSide, //
]);
const _pushDay = _DayTemplate('Empurrar', 'Push', 'push', [
  _push, _overhead, _pushAlt, _lateral, _triceps, //
]);
const _pullDay = _DayTemplate('Puxar', 'Pull', 'pull', [
  _vertical, _row, _rearDelt, _biceps, _coreAlt, //
]);
const _legsDay = _DayTemplate('Pernas', 'Legs', 'legs', [
  _squat, _hinge, _lunge, _glute, _calf, //
]);
const _mobility = _DayTemplate(
  'Core e mobilidade',
  'Core and mobility',
  'mobility',
  [
    _core, _coreAlt, _coreSide, _glute, //
  ],
);

/// Split by days, then by level. Beginners (and anyone back after more than
/// six months) stay on whole-body sessions up to four days.
List<_DayTemplate> _splitFor(int days, String level) {
  final beginner = level == 'beginner';
  if (beginner) {
    return switch (days.clamp(1, 7)) {
      1 => const [_fullA],
      2 => const [_fullA, _fullB],
      3 => const [_fullA, _fullB, _fullC],
      4 => const [_fullA, _fullB, _fullC, _fullB],
      5 => const [_upperA, _lowerA, _fullA, _upperB, _lowerB],
      6 => const [_upperA, _lowerA, _fullA, _upperB, _lowerB, _fullB],
      _ => const [
        _upperA,
        _lowerA,
        _fullA,
        _upperB,
        _lowerB,
        _fullB,
        _mobility,
      ],
    };
  }
  return switch (days.clamp(1, 7)) {
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
}

/// Exercises per session for a target duration (warm-up included). The time
/// fit may still trim this number.
int exercisesForMinutes(int minutes) => switch (minutes) {
  <= 30 => 4,
  <= 45 => 5,
  <= 60 => 6,
  _ => 7,
};

const _warmupMinutes = 5;
const _fitTolerance = 5;

/// Minutes for one exercise slot alone or paired (superset).
int _workSeconds(PlannedSlot slot) => slot.timed ? slot.reps : slot.reps * 3;

bool _isAccessoryKey(String key) => exerciseTraits[key]?.accessory ?? false;

/// Groups slots into single exercises or supersets. With [circuits], two
/// consecutive accessories form a superset.
List<List<PlannedSlot>> _groups(
  List<PlannedSlot> slots, {
  bool circuits = false,
}) {
  final groups = <List<PlannedSlot>>[];
  var i = 0;
  while (i < slots.length) {
    final slot = slots[i];
    if (circuits &&
        _isAccessoryKey(slot.exerciseKey) &&
        i + 1 < slots.length &&
        _isAccessoryKey(slots[i + 1].exerciseKey)) {
      groups.add([slot, slots[i + 1]]);
      i += 2;
    } else {
      groups.add([slot]);
      i += 1;
    }
  }
  return groups;
}

int _dayMinutesFromSlots(List<PlannedSlot> slots, {bool circuits = false}) {
  var seconds = _warmupMinutes * 60;
  for (final group in _groups(slots, circuits: circuits)) {
    if (group.length == 1) {
      final s = group.single;
      seconds += s.sets * (_workSeconds(s) + s.restSeconds);
    } else {
      final sets = group.map((s) => s.sets).reduce((a, b) => a > b ? a : b);
      final rest = group
          .map((s) => s.restSeconds)
          .reduce((a, b) => a > b ? a : b);
      seconds +=
          sets * (group.fold<int>(0, (sum, s) => sum + _workSeconds(s)) + rest);
    }
  }
  return (seconds / 60).round();
}

/// Rough session length for a traditional (non-superset) day: warm-up of
/// 5 min, then sets × (work + rest) for every slot. Shown as guidance, not as
/// a precise timer.
int estimateMinutes(Iterable<PlannedSlot> slots) =>
    _dayMinutesFromSlots(slots.toList());

/// Order used when rotating priorities across the week.
class PlanPreferencesOrder {
  static const areas = PlanPreferences.allPriorities;
}

const _prioritySlots = <String, List<_Slot>>{
  'legs': [_lunge, _squat, _calf],
  'glutes': [_glute, _hinge],
  'chest': [_pushAlt, _push],
  'back': [_row, _vertical],
  'shoulders': [_lateral, _overhead, _rearDelt],
  'arms': [_biceps, _triceps],
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

/// Used only when every template and filler slot is blocked by the user's
/// choices. Still checked against every rule.
const _lastResort = <String>[
  'glute_bridge',
  'plank',
  'dead_bug',
  'bird_dog',
  'calf_raise',
  'superman',
  'side_plank',
  'single_leg_balance',
];

const _timedSeconds = 30;
const _accessoryReps = 12;

/// Most sets a main lift may get when the time fit adds volume.
const _goalMaxSets = <String, int>{
  'strength': 5,
  'muscle': 4,
  'fat_loss': 4,
  'endurance': 3,
  'health': 4,
  'mobility': 2,
};

/// Accessories the time fit may add, in order (favourites first). Only used
/// when the session is clearly shorter than requested and the sets are capped.
const _accessoryPool = <String>[
  'calf_raise',
  'lateral_raise',
  'biceps_curl',
  'triceps_pushdown',
  'face_pull',
  'band_pull_apart',
  'superman',
  'dead_bug',
  'bird_dog',
  'side_plank',
  'plank',
  'single_leg_balance',
];

/// A session is clearly short when it is under 85% of the requested length or
/// more than 8 minutes under it.
bool _clearlyShort(int minutes, int requested) =>
    minutes < max(requested * 0.85, requested - 8);

PlannedSlot _accessorySlot(String key, int sets, int restSeconds) =>
    PlannedSlot(
      exerciseKey: key,
      sets: sets,
      reps: (exerciseTraits[key]?.timed ?? false)
          ? _timedSeconds
          : _accessoryReps,
      restSeconds: restSeconds,
    );

/// The text for a day the time fit changed, in both languages (no day label).
DayNote _fillNote({
  required int day,
  required int requested,
  required int extraSets,
  required List<String> accessories,
  required int extraCardio,
  required Map<String, (String, String)> namesOf,
}) {
  String nameOf(String key, bool en) {
    final pair = namesOf[key];
    if (pair == null) return key;
    return en ? pair.$2 : pair.$1;
  }

  final pt = <String>[];
  final en = <String>[];
  if (extraSets > 0) {
    pt.add(
      '$extraSets ${extraSets == 1 ? 'série' : 'séries'} a mais nos principais',
    );
    en.add(
      '$extraSets more ${extraSets == 1 ? 'set' : 'sets'} on the main lifts',
    );
  }
  if (accessories.isNotEmpty) {
    final single = accessories.length == 1;
    pt.add(
      '${single ? 'o exercício' : 'os exercícios'} '
      '${accessories.map((k) => nameOf(k, false)).join(', ')}',
    );
    en.add(
      '${single ? 'the exercise' : 'the exercises'} '
      '${accessories.map((k) => nameOf(k, true)).join(', ')}',
    );
  }
  if (extraCardio > 0) {
    pt.add('$extraCardio min de cardio no fim');
    en.add('$extraCardio more min of cardio at the end');
  }
  return DayNote(
    day: day,
    pt:
        'para chegar mais perto dos $requested min pedidos, '
        'acrescentámos ${pt.join(' e ')}.',
    en:
        'to get closer to the $requested min you asked for, '
        'we added ${en.join(' and ')}.',
  );
}

bool _isAccessory(String key) => _isAccessoryKey(key);

String _areaPt(String area) => switch (area) {
  'knee' => 'joelho',
  'shoulder' => 'ombro',
  'lower_back' => 'lombar',
  'wrist_elbow' => 'pulso/cotovelo',
  'hip' => 'anca',
  'neck' => 'pescoço',
  'ankle' => 'tornozelo',
  _ => area,
};

String _areaEn(String area) => switch (area) {
  'knee' => 'knee',
  'shoulder' => 'shoulder',
  'lower_back' => 'lower back',
  'wrist_elbow' => 'wrist/elbow',
  'hip' => 'hip',
  'neck' => 'neck',
  'ankle' => 'ankle',
  _ => area,
};

String _levelPt(String level) => switch (level) {
  'avoid_impact' => 'sem impacto',
  'avoid_heavy_load' => 'sem carga pesada',
  _ => 'sem exercícios que a stressem',
};

String _levelEn(String level) => switch (level) {
  'avoid_impact' => 'no impact',
  'avoid_heavy_load' => 'no heavy load',
  _ => 'no stress',
};

String _warmupPt(String focus) => switch (focus) {
  'upper' || 'push' || 'pull' =>
    'Aquecimento 5 min: círculos de ombros, rotação torácica e flexões leves ou elásticos.',
  'lower' || 'legs' =>
    'Aquecimento 5 min: círculos de anca, balanço de pernas e pontes de glúteos.',
  'mobility' => 'Aquecimento 5 min: gato-vaca e círculos de anca.',
  _ =>
    'Aquecimento 5 min: rotação de anca, ativação de glúteos e 10 agachamentos sem carga.',
};

String _warmupEn(String focus) => switch (focus) {
  'upper' || 'push' || 'pull' =>
    'Warm-up 5 min: shoulder circles, thoracic rotation and light push-ups or bands.',
  'lower' ||
  'legs' => 'Warm-up 5 min: hip circles, leg swings and glute bridges.',
  'mobility' => 'Warm-up 5 min: cat-cow and hip circles.',
  _ => 'Warm-up 5 min: hip rotation, glute activation and 10 unloaded squats.',
};

/// Double-progression rule for one exercise, in plain language.
String progressionRule(PlannedSlot slot, {required bool english}) {
  if (slot.timed) {
    return english
        ? 'When you hold ${slot.reps} s in every set, add 5 s or make it harder.'
        : 'Quando seguras ${slot.reps} s em todas as séries, acrescenta 5 s ou dificulta o exercício.';
  }
  final target = repRangeText(top: slot.reps, english: english);
  return english
      ? 'When you reach $target in every set, raise the load about 2–5% (or ~2 kg). Below that, keep the load.'
      : 'Quando fizeres $target em todas as séries, aumenta a carga cerca de 2–5% (ou ~2 kg). Abaixo disso, mantém a carga.';
}

/// Weeks of the block: progression weeks, then one deload week. [BlockWeek]
/// texts are the body only; the "Semana k" label comes from [blockPhases].
List<BlockWeek> blockSchedule(int blockWeeks) {
  final weeks = PlanPreferences.blockOptions.contains(blockWeeks)
      ? blockWeeks
      : 4;
  return [
    for (var k = 1; k <= weeks; k++)
      if (k < weeks)
        BlockWeek(
          number: k,
          deload: false,
          pt: 'progressão normal. Tenta mais uma repetição por série do que na semana anterior, sem passar do topo da faixa.',
          en: 'normal progression. Aim for one more rep per set than last week, without going past the top of the range.',
        )
      else
        BlockWeek(
          number: k,
          deload: true,
          pt: 'descarga. Cerca de 40% menos séries, mesma técnica e cargas um pouco mais leves.',
          en: 'deload. About 40% fewer sets, same technique and slightly lighter loads.',
        ),
  ];
}

/// Consecutive weeks with the same text, shown as one line: "Semanas 1–3:
/// progressão normal. …" then "Semana 4: descarga. …".
class BlockPhase {
  const BlockPhase({
    required this.fromWeek,
    required this.toWeek,
    required this.deload,
    required this.pt,
    required this.en,
  });

  final int fromWeek;
  final int toWeek;
  final bool deload;
  final String pt;
  final String en;

  String label(bool english) {
    if (fromWeek == toWeek) {
      return english ? 'Week $fromWeek' : 'Semana $fromWeek';
    }
    return english ? 'Weeks $fromWeek–$toWeek' : 'Semanas $fromWeek–$toWeek';
  }

  String text(bool english) => '${label(english)}: ${english ? en : pt}';
}

/// Groups consecutive weeks whose text is identical.
List<BlockPhase> blockPhases(List<BlockWeek> weeks) {
  final phases = <BlockPhase>[];
  for (final week in weeks) {
    final last = phases.isEmpty ? null : phases.last;
    if (last != null &&
        last.deload == week.deload &&
        last.pt == week.pt &&
        last.en == week.en) {
      phases[phases.length - 1] = BlockPhase(
        fromWeek: last.fromWeek,
        toWeek: week.number,
        deload: week.deload,
        pt: week.pt,
        en: week.en,
      );
    } else {
      phases.add(
        BlockPhase(
          fromWeek: week.number,
          toWeek: week.number,
          deload: week.deload,
          pt: week.pt,
          en: week.en,
        ),
      );
    }
  }
  return phases;
}

/// Builds a plan from the wizard answers.
///
/// [equipmentOf] maps every catalogue exercise key to its equipment
/// requirement string (see `exercise_traits.dart`). [namesOf] optionally maps
/// keys to display names (PT, EN) for the substitution notes.
///
/// Throws [StateError] for a user who is blocked (under 18).
GeneratedPlan buildPlan(
  PlanPreferences prefs,
  Map<String, String> equipmentOf, {
  Map<String, (String, String)> namesOf = const {},
}) {
  if (prefs.isBlocked) {
    throw StateError('Plans are not generated for under-18 users in v1.');
  }
  final level = levelOf(prefs.experience);
  final returning = prefs.detraining == '1to6m' || prefs.detraining == 'gt6m';
  final splitLevel = prefs.detraining == 'gt6m' ? 'beginner' : level;
  final days = prefs.weekdays.isEmpty ? 3 : prefs.weekdays.length.clamp(1, 7);
  final schedule = prefs.weekdays.isEmpty
      ? defaultWeekdays(days)
      : prefs.weekdays;
  final split = _splitFor(days, splitLevel);
  final goal = goalKeyOf(prefs.goal);
  final sixtyPlus = prefs.ageRange == '60plus';
  final impactOk = prefs.impactAllowed && !sixtyPlus;
  final available = prefs.equipment;
  final avoided = prefs.avoidedExercises;
  final favourites = prefs.favouriteExercises;
  final rx = prescriptionFor(
    goal,
    prefs.experience,
    detraining: prefs.detraining,
    rest: prefs.rest,
  );
  final accessoryRest = _restFor(60 + (sixtyPlus ? 30 : 0), prefs.rest);
  final accessorySets = returning ? 2 : 3;
  final mainRest = sixtyPlus ? rx.restSeconds + 30 : rx.restSeconds;

  // Facts gathered while building, used for the notes.
  final swaps = <String, (String, String)>{}; // rejected -> (chosen, area)
  final limitedAreas = <String>{};
  var impactRemoved = false;

  bool allowedByEquipment(String key) {
    final requirement = equipmentOf[key];
    if (requirement == null || !exerciseTraits.containsKey(key)) return false;
    return equipmentCovers(requirement, available);
  }

  /// Why [key] cannot be used, or null when it can. Records no facts.
  String? quietBlock(String key) {
    if (!allowedByEquipment(key)) return 'equipment';
    if (avoided.contains(key)) return 'avoided';
    return limitationConflict(
      key,
      limitAreas: prefs.limitAreas,
      impactAllowed: impactOk,
    );
  }

  /// Why [key] cannot be used, or null when it can. Records the swap facts
  /// used by the notes.
  String? blockReason(String key) {
    final reason = quietBlock(key);
    if (reason == 'impact') impactRemoved = true;
    if (reason != null &&
        reason != 'equipment' &&
        reason != 'avoided' &&
        reason != 'impact') {
      limitedAreas.add(reason);
    }
    return reason;
  }

  List<String> ordered(_Slot slot) => [
    ...slot.where(favourites.contains),
    ...slot.where((key) => !favourites.contains(key)),
  ];

  final planned = <PlannedDay>[];
  final warnings = <DayNote>[];
  final fillNotes = <DayNote>[];
  final counts = <String, int>{};
  for (var i = 0; i < days; i++) {
    final template = split[i];
    // Repeated templates (6-7 days) get a number suffix.
    final seen = counts.update(template.pt, (v) => v + 1, ifAbsent: () => 1);
    final suffix = seen > 1 ? ' $seen' : '';
    final keys = <String>[];

    void take(_Slot slot) {
      final candidates = ordered(slot);
      String? rejectedBy;
      String? rejectedKey;
      for (final key in candidates) {
        if (keys.contains(key)) continue;
        final reason = blockReason(key);
        if (reason == null) {
          if (rejectedKey != null && rejectedBy != null) {
            swaps.putIfAbsent(rejectedKey, () => (key, rejectedBy!));
          }
          keys.add(key);
          return;
        }
        if (rejectedKey == null &&
            reason != 'equipment' &&
            reason != 'avoided' &&
            reason != 'impact') {
          rejectedKey = key;
          rejectedBy = reason;
        }
      }
    }

    final target = exercisesForMinutes(prefs.sessionMinutes);
    final ordering = [
      for (final p in PlanPreferencesOrder.areas)
        if (prefs.priorities.contains(p)) p,
    ];
    // Priorities add at most two accessories and never replace the template.
    final spare = target - template.slots.length;
    final extras = ordering.isEmpty
        ? 0
        : spare.clamp(1, ordering.length >= 2 ? 2 : 1);
    final baseCount = (target - extras).clamp(3, target);
    for (final slot in template.slots) {
      if (keys.length >= baseCount) break;
      take(slot);
    }
    for (var e = 0; e < extras && ordering.isNotEmpty; e++) {
      final area = ordering[(i * extras + e) % ordering.length];
      for (final slot in _prioritySlots[area] ?? const <_Slot>[]) {
        final before = keys.length;
        take(slot);
        if (keys.length > before) break;
      }
    }
    // Favourites fill spare room (only the ones the user can use).
    for (final key in favourites) {
      if (keys.length >= target) break;
      if (keys.contains(key) || blockReason(key) != null) continue;
      keys.add(key);
    }
    if (sixtyPlus && !keys.contains('single_leg_balance')) {
      take(_balance);
    }
    for (final slot in [...template.slots, ..._fillerSlots]) {
      if (keys.length >= target) break;
      take(slot);
    }
    for (final key in _lastResort) {
      if (keys.length >= 3) break;
      if (keys.contains(key) || blockReason(key) != null) continue;
      keys.add(key);
    }

    final slots = [
      for (final key in keys)
        if (_isAccessory(key))
          _accessorySlot(key, accessorySets, accessoryRest)
        else
          PlannedSlot(
            exerciseKey: key,
            sets: rx.sets,
            reps: rx.reps,
            restSeconds: mainRest,
          ),
    ];

    // Fit the session: trim the last accessory first, then drop sets, then
    // shorten rests. The cardio finisher takes its share of the session.
    final cardioMinutes = switch (prefs.cardio) {
      'finisher' => prefs.sessionMinutes >= 30 ? 10 : 5,
      // Dedicated cardio is 20 minutes, or 10 in sessions shorter than 45.
      'dedicated' => prefs.sessionMinutes >= 45 ? 20 : 10,
      _ => 0,
    };
    final budget = prefs.sessionMinutes - cardioMinutes;
    final circuits = prefs.style == 'circuits';
    var fitted = List<PlannedSlot>.from(slots);
    bool over() =>
        _dayMinutesFromSlots(fitted, circuits: circuits) >
        budget + _fitTolerance;
    // The balance exercise for 60+ is protected: it is never trimmed.
    while (over() && fitted.length > 3) {
      final index = fitted.lastIndexWhere(
        (s) => _isAccessory(s.exerciseKey) && s.exerciseKey != _balanceKey,
      );
      if (index >= 0) {
        fitted.removeAt(index);
        continue;
      }
      // No accessories left to trim: drop the last main lift (never the
      // balance exercise), so the session can still fit.
      final main = fitted.lastIndexWhere((s) => s.exerciseKey != _balanceKey);
      if (main < 0) break;
      fitted.removeAt(main);
    }
    if (over()) {
      fitted = [
        for (final s in fitted)
          _isAccessory(s.exerciseKey)
              ? PlannedSlot(
                  exerciseKey: s.exerciseKey,
                  sets: 2,
                  reps: s.reps,
                  restSeconds: s.restSeconds,
                )
              : s,
      ];
    }
    if (over()) {
      fitted = [
        for (final s in fitted)
          PlannedSlot(
            exerciseKey: s.exerciseKey,
            sets: s.sets,
            reps: s.reps,
            restSeconds: s.restSeconds > 60 ? 60 : s.restSeconds,
          ),
      ];
    }
    // Last resort for very short sessions: two sets and shorter rests.
    if (over()) {
      fitted = [
        for (final s in fitted)
          PlannedSlot(
            exerciseKey: s.exerciseKey,
            sets: 2,
            reps: s.reps,
            restSeconds: s.restSeconds > 45 ? 45 : s.restSeconds,
          ),
      ];
    }

    // Time fill: a session clearly shorter than requested gets more volume, in
    // this order: one more set on the main lift with the fewest sets (up to the
    // goal's cap), then one accessory the constraints allow, then 5 more
    // minutes of cardio finisher. Each step must keep the estimate within the
    // requested length plus the tolerance, so the fill never overshoots.
    var cardioUsed = cardioMinutes;
    final requested = prefs.sessionMinutes;
    final ceiling = requested + _fitTolerance;
    final setsBeforeFill = {for (final s in fitted) s.exerciseKey: s.sets};
    final mainCap = max(rx.sets, _goalMaxSets[goal] ?? rx.sets);
    final addedAccessories = <String>[];
    int minutesOf(List<PlannedSlot> slots, int cardio) =>
        _dayMinutesFromSlots(slots, circuits: circuits) + cardio;
    var total = minutesOf(fitted, cardioUsed);
    while (_clearlyShort(total, requested)) {
      var changed = false;

      var pick = -1;
      for (var m = 0; m < fitted.length; m++) {
        final s = fitted[m];
        if (_isAccessory(s.exerciseKey) || s.sets >= mainCap) continue;
        if (pick < 0 || s.sets < fitted[pick].sets) pick = m;
      }
      if (pick >= 0) {
        final s = fitted[pick];
        final trial = List<PlannedSlot>.from(fitted)
          ..[pick] = PlannedSlot(
            exerciseKey: s.exerciseKey,
            sets: s.sets + 1,
            reps: s.reps,
            restSeconds: s.restSeconds,
          );
        if (minutesOf(trial, cardioUsed) <= ceiling) {
          fitted = trial;
          changed = true;
        }
      }

      if (!changed) {
        final pool = [
          ..._accessoryPool.where(favourites.contains),
          ..._accessoryPool.where((key) => !favourites.contains(key)),
        ];
        for (final key in pool) {
          if (keys.contains(key) || quietBlock(key) != null) continue;
          final trial = [
            ...fitted,
            _accessorySlot(key, accessorySets, accessoryRest),
          ];
          if (minutesOf(trial, cardioUsed) > ceiling) continue;
          fitted = trial;
          keys.add(key);
          addedAccessories.add(key);
          changed = true;
          break;
        }
      }

      if (!changed && prefs.cardio != 'none') {
        final cap = prefs.cardio == 'dedicated' ? 30 : 15;
        if (cardioUsed + 5 <= cap &&
            minutesOf(fitted, cardioUsed + 5) <= ceiling) {
          cardioUsed += 5;
          changed = true;
        }
      }

      if (!changed) break;
      total = minutesOf(fitted, cardioUsed);
    }

    final extraSets = [
      for (final s in fitted)
        if (!_isAccessory(s.exerciseKey))
          s.sets - (setsBeforeFill[s.exerciseKey] ?? s.sets),
    ].fold(0, (sum, extra) => sum + extra);
    if (extraSets > 0 ||
        addedAccessories.isNotEmpty ||
        cardioUsed > cardioMinutes) {
      fillNotes.add(
        _fillNote(
          day: i + 1,
          requested: requested,
          extraSets: extraSets,
          accessories: addedAccessories,
          extraCardio: cardioUsed - cardioMinutes,
          namesOf: namesOf,
        ),
      );
    }

    // Supersets: pair consecutive accessories in circuits mode.
    final grouped = <PlannedSlot>[];
    var group = 0;
    for (final g in _groups(fitted, circuits: circuits)) {
      if (g.length == 2) {
        group += 1;
        grouped.add(_withGroup(g[0], group));
        grouped.add(_withGroup(g[1], group));
      } else {
        grouped.add(g.single);
      }
    }

    if (grouped.length < 3) {
      warnings.add(
        DayNote(
          day: i + 1,
          pt: 'só há ${grouped.length} exercício(s) compatíveis com o teu equipamento e limitações. Acrescenta equipamento ou revê as limitações.',
          en: 'only ${grouped.length} exercise(s) fit your equipment and limitations. Add equipment or review your limitations.',
        ),
      );
    }
    planned.add(
      PlannedDay(
        namePt: '${template.pt}$suffix',
        nameEn: '${template.en}$suffix',
        weekday: schedule[i],
        exercises: grouped,
        cardioMinutes: cardioUsed,
        cardioType: cardioUsed == 0 ? null : _cardioFor(prefs, impactOk),
        estimatedMinutes:
            _dayMinutesFromSlots(grouped, circuits: circuits) + cardioUsed,
        warmupPt: _warmupPt(template.focus),
        warmupEn: _warmupEn(template.focus),
      ),
    );
  }

  final notes = _notes(
    prefs: prefs,
    level: level,
    splitLevel: splitLevel,
    days: days,
    returning: returning,
    goal: goal,
    rx: rx,
    swaps: swaps,
    limitedAreas: limitedAreas,
    impactRemoved: impactRemoved,
    impactOk: impactOk,
    planned: planned,
    namesOf: namesOf,
    cardioMinutes: planned.isEmpty ? 0 : planned.first.cardioMinutes,
    sixtyPlus: sixtyPlus,
    fillNotes: groupDayNotes(fillNotes),
  );

  final goalPt = _goalPt(goal);
  final goalEn = _goalEn(goal);
  return GeneratedPlan(
    titlePt: '$goalPt · $days dias',
    titleEn: '$goalEn · $days days',
    days: planned,
    blockWeeks: PlanPreferences.blockOptions.contains(prefs.blockWeeks)
        ? prefs.blockWeeks
        : 4,
    weeks: blockSchedule(prefs.blockWeeks),
    notes: notes,
    warnings: groupDayNotes(warnings),
  );
}

PlannedSlot _withGroup(PlannedSlot slot, int group) => PlannedSlot(
  exerciseKey: slot.exerciseKey,
  sets: slot.sets,
  reps: slot.reps,
  restSeconds: slot.restSeconds,
  supersetGroup: group,
);

String _cardioFor(PlanPreferences prefs, bool impactOk) {
  final type = prefs.cardioType;
  if (!impactOk && (type == 'run' || type == 'hiit')) return 'walk';
  return type;
}

String _goalPt(String goal) => switch (goal) {
  'fat_loss' => 'Perder gordura',
  'muscle' => 'Ganhar músculo',
  'strength' => 'Força',
  'endurance' => 'Resistência',
  'mobility' => 'Mobilidade',
  _ => 'Saúde e rotina',
};

String _goalEn(String goal) => switch (goal) {
  'fat_loss' => 'Fat loss',
  'muscle' => 'Build muscle',
  'strength' => 'Strength',
  'endurance' => 'Endurance',
  'mobility' => 'Mobility',
  _ => 'Health and routine',
};

List<PlanNote> _notes({
  required PlanPreferences prefs,
  required String level,
  required String splitLevel,
  required int days,
  required bool returning,
  required String goal,
  required Prescription rx,
  required Map<String, (String, String)> swaps,
  required Set<String> limitedAreas,
  required bool impactRemoved,
  required bool impactOk,
  required List<PlannedDay> planned,
  required Map<String, (String, String)> namesOf,
  required int cardioMinutes,
  required bool sixtyPlus,
  required List<PlanNote> fillNotes,
}) {
  String nameOf(String key, bool en) {
    final pair = namesOf[key];
    if (pair == null) return key;
    return en ? pair.$2 : pair.$1;
  }

  final levelPt = switch (level) {
    'intermediate' => 'intermédio',
    'advanced' => 'avançado',
    _ => 'iniciante',
  };
  final levelEn = switch (level) {
    'intermediate' => 'intermediate',
    'advanced' => 'advanced',
    _ => 'beginner',
  };
  final splitPt = splitLevel == 'beginner'
      ? 'treino de corpo inteiro'
      : 'divisão por grupos';
  final splitEn = splitLevel == 'beginner'
      ? 'whole-body training'
      : 'split by muscle groups';
  final notes = <PlanNote>[
    PlanNote(
      'Escolhemos $splitPt porque treinas $days dias e o nível é $levelPt.',
      'We chose $splitEn because you train $days days and your level is $levelEn.',
    ),
    PlanNote(
      'Cada treino usa ${rx.sets} séries de ${repRangeText(top: rx.reps, bottom: rx.repMin, english: false)}'
          ' com ${rx.restSeconds} s de descanso. Deixa 2–3 repetições em reserva.',
      'Each session uses ${rx.sets} sets of ${repRangeText(top: rx.reps, bottom: rx.repMin, english: true)}'
          ' with ${rx.restSeconds} s rest. Leave 2–3 reps in reserve.',
    ),
    ...fillNotes,
  ];
  if (returning) {
    notes.add(
      const PlanNote(
        'Voltas a treinar depois de uma pausa: começamos com menos uma série por exercício.',
        'You are returning after a break: we start with one fewer set per exercise.',
      ),
    );
  }
  for (final entry in swaps.entries) {
    final (chosen, area) = entry.value;
    notes.add(
      PlanNote(
        'Trocámos ${nameOf(entry.key, false)} por ${nameOf(chosen, false)}'
            ' por causa da ${_areaPt(area)} (${_levelPt(prefs.limitAreas[area] ?? '')}).',
        'We swapped ${nameOf(entry.key, true)} for ${nameOf(chosen, true)}'
            ' because of your ${_areaEn(area)} (${_levelEn(prefs.limitAreas[area] ?? '')}).',
      ),
    );
  }
  if (limitedAreas.isNotEmpty && swaps.isEmpty) {
    notes.add(
      const PlanNote(
        'Os exercícios que stressam as zonas indicadas ficaram de fora.',
        'Exercises that stress the areas you marked were left out.',
      ),
    );
  }
  if (impactRemoved || !impactOk) {
    notes.add(
      PlanNote(
        sixtyPlus
            ? 'Para 60+ privilegiamos exercícios sem impacto e incluímos equilíbrio.'
            : 'Sem impacto: saltos e afundos dinâmicos ficaram de fora.',
        sixtyPlus
            ? 'For 60+ we prefer low-impact exercises and include balance work.'
            : 'No impact: jumps and dynamic lunges were left out.',
      ),
    );
  }
  final minutes = planned.isEmpty ? 0 : planned.first.estimatedMinutes;
  final session = prefs.sessionMinutes;
  notes.add(
    PlanNote(
      'Tempo: cerca de $minutes min por treino, incluindo 5 min de aquecimento, para os $session min pedidos.',
      'Time: about $minutes min per session, including a 5 min warm-up, for the $session min you asked for.',
    ),
  );
  if (prefs.style == 'circuits') {
    notes.add(
      const PlanNote(
        'Circuitos: os acessórios são feitos em pares, sem descanso entre os dois exercícios do par.',
        'Circuits: accessories are done in pairs, with no rest between the two exercises of a pair.',
      ),
    );
  }
  if (cardioMinutes > 0) {
    final type = planned.isEmpty
        ? 'walk'
        : (planned.first.cardioType ?? 'walk');
    final typePt = switch (type) {
      'run' => 'corrida',
      'bike' => 'bicicleta',
      'row' => 'remo',
      'hiit' => 'HIIT',
      _ => 'caminhada rápida',
    };
    final typeEn = switch (type) {
      'run' => 'running',
      'bike' => 'cycling',
      'row' => 'rowing',
      'hiit' => 'HIIT',
      _ => 'brisk walking',
    };
    notes.add(
      PlanNote(
        prefs.cardio == 'dedicated'
            ? '$cardioMinutes min de $typePt no fim de cada treino (cardio dedicado: um dia só de cardio ainda não é gerado).'
            : '$cardioMinutes min de $typePt no fim de cada treino.',
        prefs.cardio == 'dedicated'
            ? '$cardioMinutes min of $typeEn at the end of each session (dedicated cardio: a cardio-only day is not generated yet).'
            : '$cardioMinutes min of $typeEn at the end of each session.',
      ),
    );
  }
  if (prefs.dumbbellMaxKg != null) {
    notes.add(
      PlanNote(
        'Os halteres vão até ${prefs.dumbbellMaxKg} kg: quando chegares lá, aumenta repetições ou o tempo sob tensão.',
        'Your heaviest dumbbell is ${prefs.dumbbellMaxKg} kg: once you reach it, add reps or time under tension.',
      ),
    );
  }
  notes.add(
    const PlanNote(
      'Progressão dupla: primeiro sobes as repetições até ao topo da faixa; depois sobes a carga cerca de 2–5%.',
      'Double progression: first add reps up to the top of the range; then raise the load about 2–5%.',
    ),
  );
  return notes;
}

/// Short weekday name (Seg / Mon / Lun / Mo), from the language tables.
String weekdayShort(int weekday, VyroStrings t) =>
    t.get('wdShort${weekday.clamp(1, 7)}');

/// Full weekday name (Segunda-feira / Monday / Lunedì / Montag).
String weekdayLong(int weekday, VyroStrings t) =>
    t.get('wdLong${weekday.clamp(1, 7)}');

/// Version 1 entry point, kept for existing callers and tests. It maps the
/// arguments onto [PlanPreferences] and calls [buildPlan].
GeneratedPlan generatePlan({
  required int daysPerWeek,
  required String goal,
  required String experience,
  required Set<String> available,
  required Map<String, String> equipmentOf,
  List<int>? weekdays,
  int sessionMinutes = 45,
  Set<String> priorities = const {},
}) {
  final days = daysPerWeek.clamp(1, 7);
  return buildPlan(
    PlanPreferences(
      goal: goalKeyOf(goal),
      experience: experience,
      weekdays: weekdays != null && weekdays.length == days
          ? weekdays
          : defaultWeekdays(days),
      sessionMinutes: sessionMinutes,
      equipment: available,
      priorities: priorities,
    ),
    equipmentOf,
  );
}
