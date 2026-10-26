/// Static facts about each catalogue exercise that the generator needs:
/// equipment, which joint areas it loads, and whether it is high impact.
///
/// The joint loads are a simplified, conservative classification for planning
/// only. They are not a medical or biomechanical assessment, and the app never
/// presents them as one.
library;

/// Load a movement puts on a joint area.
///   heavy = loaded or range-heavy, light = low load or controlled range.
const _heavy = 'heavy';
const _light = 'light';

/// User-selected limitation levels (see PlanPreferences.limitLevels).
const avoidImpact = 'avoid_impact';
const avoidHeavyLoad = 'avoid_heavy_load';
const avoidCompletely = 'avoid_completely';

class ExerciseTraits {
  const ExerciseTraits({
    required this.equipment,
    this.loads = const {},
    this.impact = false,
    this.timed = false,
    this.accessory = false,
  });

  /// Equipment requirement, in the catalogue string format. See
  /// [equipmentAlternatives].
  final String equipment;

  /// Joint area -> 'heavy' or 'light'.
  final Map<String, String> loads;

  /// Jumps, dynamic lunges and other high-impact movements.
  final bool impact;

  /// Prescribed in seconds, not repetitions.
  final bool timed;

  /// Isolation or core work: shorter rest, fewer sets, first to be trimmed.
  final bool accessory;
}

const exerciseTraits = <String, ExerciseTraits>{
  'goblet_squat': ExerciseTraits(
    equipment: 'halteres',
    loads: {'knee': _heavy, 'hip': _light, 'lower_back': _light},
  ),
  'kettlebell_squat': ExerciseTraits(
    equipment: 'kettlebell',
    loads: {'knee': _heavy, 'hip': _light, 'lower_back': _light},
  ),
  'barbell_squat': ExerciseTraits(
    equipment: 'barra olímpica + rack',
    loads: {'knee': _heavy, 'hip': _heavy, 'lower_back': _heavy},
  ),
  'box_squat': ExerciseTraits(
    equipment: 'banco',
    loads: {'knee': _light, 'hip': _light, 'lower_back': _light},
  ),
  'leg_press': ExerciseTraits(
    equipment: 'máquinas',
    loads: {'knee': _light, 'hip': _light},
  ),
  'split_squat': ExerciseTraits(
    equipment: 'peso corporal ou halteres',
    loads: {'knee': _light, 'hip': _light},
  ),
  'reverse_lunge': ExerciseTraits(
    equipment: 'peso corporal ou halteres',
    loads: {'knee': _heavy, 'hip': _light},
    impact: true,
  ),
  'step_up': ExerciseTraits(
    equipment: 'step ou banco',
    loads: {'knee': _light, 'hip': _light},
  ),
  'hip_hinge': ExerciseTraits(
    equipment: 'halteres',
    loads: {'lower_back': _heavy, 'hip': _heavy},
  ),
  'hip_thrust': ExerciseTraits(
    equipment: 'banco',
    loads: {'lower_back': _light, 'hip': _light},
  ),
  'glute_bridge': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'lower_back': _light},
  ),
  'calf_raise': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'ankle': _light},
    accessory: true,
  ),
  'single_leg_balance': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'ankle': _light},
    timed: true,
    accessory: true,
  ),
  'dumbbell_press': ExerciseTraits(
    equipment: 'halteres',
    loads: {'shoulder': _heavy, 'wrist_elbow': _light},
  ),
  'bench_press': ExerciseTraits(
    equipment: 'barra olímpica + banco',
    loads: {'shoulder': _heavy, 'wrist_elbow': _heavy},
  ),
  'push_up': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'shoulder': _light, 'wrist_elbow': _light},
  ),
  'pike_push_up': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'shoulder': _heavy, 'wrist_elbow': _light, 'neck': _light},
  ),
  'shoulder_press': ExerciseTraits(
    equipment: 'halteres',
    loads: {'shoulder': _heavy, 'neck': _light},
  ),
  'landmine_press': ExerciseTraits(
    equipment: 'barra olímpica',
    loads: {'shoulder': _light, 'lower_back': _light},
  ),
  'lateral_raise': ExerciseTraits(
    equipment: 'halteres',
    loads: {'shoulder': _light},
    accessory: true,
  ),
  'face_pull': ExerciseTraits(
    equipment: 'cabo',
    loads: {'shoulder': _light, 'neck': _light},
    accessory: true,
  ),
  'band_pull_apart': ExerciseTraits(
    equipment: 'elásticos',
    loads: {'shoulder': _light},
    accessory: true,
  ),
  'seated_row': ExerciseTraits(
    equipment: 'cabo',
    loads: {'lower_back': _light, 'shoulder': _light},
  ),
  'dumbbell_row': ExerciseTraits(
    equipment: 'halteres',
    loads: {'lower_back': _light, 'shoulder': _light},
  ),
  'trx_row': ExerciseTraits(
    equipment: 'trx',
    loads: {'shoulder': _light, 'wrist_elbow': _light},
  ),
  'lat_pulldown': ExerciseTraits(
    equipment: 'cabo',
    loads: {'shoulder': _light, 'lower_back': _light},
  ),
  'pull_up': ExerciseTraits(
    equipment: 'barra de elevações',
    loads: {'shoulder': _heavy, 'wrist_elbow': _light},
  ),
  'superman': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'lower_back': _light, 'neck': _light},
    accessory: true,
  ),
  'plank': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'wrist_elbow': _light, 'shoulder': _light, 'lower_back': _light},
    timed: true,
    accessory: true,
  ),
  'side_plank': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'shoulder': _light, 'wrist_elbow': _light, 'lower_back': _light},
    timed: true,
    accessory: true,
  ),
  'dead_bug': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'lower_back': _light},
    accessory: true,
  ),
  'bird_dog': ExerciseTraits(
    equipment: 'peso corporal',
    loads: {'lower_back': _light, 'shoulder': _light},
    accessory: true,
  ),
  'biceps_curl': ExerciseTraits(
    equipment: 'halteres',
    loads: {'wrist_elbow': _light},
    accessory: true,
  ),
  'triceps_pushdown': ExerciseTraits(
    equipment: 'cabo',
    loads: {'wrist_elbow': _light},
    accessory: true,
  ),
};

/// Equipment ids a catalogue `equipment` string needs. `ou` separates
/// alternatives (any one is enough), `+` separates requirements (all needed).
/// Returns groups: every group must be satisfied (AND), each group needs any
/// one of its options (OR).
List<List<String>> equipmentAlternatives(String requirement) {
  final groups = <List<String>>[];
  for (final part in requirement.toLowerCase().split('+')) {
    final options = <String>[];
    for (final alt in part.split(' ou ')) {
      final id = _equipmentIdFor(alt.trim());
      if (id != null) options.add(id);
    }
    if (options.isNotEmpty) groups.add(options);
  }
  return groups;
}

/// Whether the user's equipment covers a catalogue requirement string.
bool equipmentCovers(String requirement, Set<String> available) {
  final groups = equipmentAlternatives(requirement);
  if (groups.isEmpty) return false;
  return groups.every((options) => options.any(available.contains));
}

String? _equipmentIdFor(String text) {
  if (text.isEmpty) return null;
  if (text.startsWith('peso corporal')) return 'bodyweight';
  if (text.startsWith('halteres')) return 'dumbbells';
  if (text.startsWith('barra olímpica')) return 'barbell';
  if (text.startsWith('rack')) return 'rack';
  if (text.startsWith('banco')) return 'bench';
  if (text.startsWith('elásticos')) return 'bands';
  if (text.startsWith('kettlebell')) return 'kettlebell';
  if (text.startsWith('barra de elevações')) return 'pullup_bar';
  if (text.startsWith('máquinas')) return 'machines';
  if (text.startsWith('cabo')) return 'cable';
  if (text.startsWith('trx')) return 'trx';
  if (text.startsWith('step')) return 'step';
  return null;
}

/// Why an exercise is excluded, or null when it is allowed. [limitAreas] maps
/// joint area -> limitation level. [impactAllowed] false removes every
/// high-impact movement, whatever the joints.
String? limitationConflict(
  String key, {
  required Map<String, String> limitAreas,
  required bool impactAllowed,
}) {
  final traits = exerciseTraits[key];
  if (traits == null) return 'unknown';
  if (!impactAllowed && traits.impact) return 'impact';
  for (final entry in limitAreas.entries) {
    final load = traits.loads[entry.key];
    if (load == null) continue;
    final level = entry.value;
    if (level == avoidCompletely) return entry.key;
    if (level == avoidHeavyLoad && load == _heavy) return entry.key;
    if (level == avoidImpact && traits.impact) return entry.key;
  }
  // avoid_impact on an area also removes its impact movements, even when the
  // area is not loaded by the movement itself (e.g. knee: no jumps anywhere).
  if (traits.impact && limitAreas.values.any((level) => level == avoidImpact)) {
    return 'impact';
  }
  return null;
}
