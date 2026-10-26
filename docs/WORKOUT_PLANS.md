# Workout plans: questions, rules and limits

Plans are generated on the device by deterministic rules. The on-device model never chooses exercises, sets, reps or rest. At most it may rephrase the generator's facts in one sentence, and that sentence is checked before it is shown (`domain/ai_plan.dart`).

Every plan is an editable starting point. It is not a medical, rehabilitation or safety prescription. VYRO never says a movement is correct or safe.

## Questions (wizard, in order)

| # | Step | Answers | Notes |
|---|------|---------|-------|
| 1 | Goal | Perder gordura, ganhar músculo, força, resistência, saúde e rotina, mobilidade; optional secondary goal | Secondary goal is shown in the review and stored; it does not change sets or reps yet |
| 2 | Experience | Nunca treinei, menos de 6 meses, 6 a 24 meses, mais de 2 anos | |
| 2b | Detraining | Não estive parado(a), menos de 1 mês, 1 a 6 meses, mais de 6 meses | Only shown after some experience |
| 3 | Days | Any weekday selection (at least one) | |
| 4 | Session length | 20, 30, 45, 60, 75, 90 min | Exercises per session come from the length, then the time fit trims them |
| 5 | Place | Casa, ginásio, exterior, misto | Only changes which equipment is offered |
| 6 | Equipment | Peso corporal, halteres, barra olímpica e discos, rack, banco, elásticos, kettlebell, barra de elevações, máquinas, cabo e polias, TRX, step | Heaviest dumbbell (kg, optional) only when dumbbells are chosen |
| 7 | Limitations (skippable) | Per area (joelho, ombro, lombar, pulso e cotovelo, anca, pescoço, tornozelo): evitar impacto / evitar carga pesada / evitar totalmente; free text | Medical note always shown |
| 8 | Focus (skippable) | Balanced or priority areas (pernas, glúteos, peito, costas, ombros, braços, core) | Priorities add up to two accessories; they never replace the template |
| 9 | Exercises (skippable) | Search the catalogue; mark avoided or favourite | Favourites move first within their slot and fill spare room |
| 10 | Cardio | Nenhum, no fim do treino (10 min; 5 min in sessions under 30), cardio dedicado (20 min; 10 min under 45); type walk / run / bike / row / HIIT; impact yes/no | Dedicated cardio is a finisher, not a separate day (see limits) |
| 11 | Style | Traditional sets or circuits (accessories in pairs); rest short / normal / long | |
| 12 | Context (skippable) | Age: under 18 (blocked), 18–39, 40–59, 60+, or prefer not to say; daily activity | Under 18 cannot continue |
| 13 | Block | 4, 6 or 8 weeks | Last week is a deload |
| 14 | Review | Every answer with an edit link; generate; preview; save | |

## Generator rules

### Split (by days and level)
- Beginners (never / under 6 months) and anyone back after more than 6 months: whole-body sessions up to 4 days (A, B, C, B). 5–6 days: upper/lower with full-body days.
- Experienced: 1 day full body; 2 full body A/B; 3 full body A/B/C; 4 upper A, lower A, upper B, lower B; 5 push, pull, legs, upper A, lower B; 6 push, pull, legs ×2; 7 adds a core and mobility day.
- Repeated templates get a number suffix ("Corpo inteiro B 2").

### Exercise choice
Each template slot is a list of alternatives. The first alternative that passes every rule is taken, and no exercise repeats within a day:
1. Equipment: the user's equipment covers the requirement (`exercise_traits.dart`, `equipmentCovers`).
2. Avoided list: never used.
3. Joint limitations (`limitationConflict`):
   - avoid_impact: impact movements (jumps, dynamic lunges) are removed.
   - avoid_heavy_load: exercises that load that area heavily are removed; light ones stay.
   - avoid_completely: any exercise that loads that area is removed.
4. Impact not allowed, or age 60+: impact movements are removed.
5. Favourites are tried first within a slot.

The joint loads are a simplified, conservative classification for planning, not a biomechanical assessment.

### Substitution table (main cases)

| Limitation | Removed | Used instead (in slot order) |
|---|---|---|
| Joelho, evitar impacto | reverse lunge (impact) | split squat, step-up, leg press, box squat |
| Joelho, evitar carga pesada | goblet squat, barbell squat (heavy knee) | kettlebell squat (if owned), box squat, leg press, split squat |
| Joelho, evitar totalmente | every squat and lunge that loads the knee | hip thrust, glute bridge, planks, upper-body work |
| Ombro, evitar carga pesada | shoulder press, dumbbell press, bench press, pike push-up, pull-up (heavy shoulder) | push-up, landmine press (light), lateral raise, face pull, band pull-apart |
| Lombar, evitar carga pesada | hip hinge (Romanian deadlift), barbell squat | hip thrust, glute bridge, dead bug, bird dog |
| Pulso/cotovelo, evitar totalmente | push-up, plank (loaded wrists/elbows), triceps work | depends on the slot; the generator reports a shortage if nothing fits |
| Sem impacto (preferência) | reverse lunge, running/HIIT cardio | walking or bike for cardio |
| 60+ | impact movements | adds single-leg balance to every day (never trimmed for time) |

Every substitution is written into the plan notes ("Trocámos X por Y por causa da …").

### Prescription (sets × top of rep range, rest)

| Goal | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Força | 3 × 6–8, 120 s | 4 × 4–6, 150 s | 5 × 3–5, 180 s |
| Ganhar músculo | 3 × 8–12, 75 s | 4 × 8–12, 90 s | 4 × 8–12, 90 s |
| Perder gordura | 3 × 12–15, 60 s | 3 × 12–15, 60 s | 4 × 12–15, 60 s |
| Resistência | 2 × 15–20, 45 s | 3 × 15–20, 45 s | 3 × 15–20, 45 s |
| Saúde e rotina | 3 × 10–12, 75 s | 3 × 10–12, 90 s | 3 × 10–12, 90 s |
| Mobilidade | 2 × 10–12, 45 s | same | same |

- Returning after 1–6 months or after more than 6 months: one fewer set on main lifts (minimum 2), and accessories drop to 2 sets.
- Rest preference scales rest: short ×0.75, long ×1.3, rounded to 15 s.
- Age 60+: +30 s rest.
- Accessories: 3 sets × 12 reps (or 30 s for timed holds), 60 s rest.
- Guidance on effort: leave 2–3 reps in reserve.

### Time fit
- Estimate per slot: sets × (work + rest). Work is 3 s per rep, or the seconds for timed holds. Warm-up is 5 min.
- Circuits: two consecutive accessories form a superset; time is sets × (work A + work B + rest).
- Fit order: remove the last accessory (never the balance exercise), then accessory sets → 2, then rests → 60 s, then all sets → 2 with rests ≤ 45 s, and finally the last main lift. The fit stops at three exercises.
- Target: estimated minutes ≤ session length (minus cardio) + 5 min tolerance whenever a day has more than three exercises. If the minimum cannot fit, the plan says so.

### Time fill (under-filled days)
- A day is short when its estimate (including cardio) is under 85% of the requested length or more than 8 min under it.
- Steps, repeated until the day is no longer short. Each step must keep the estimate ≤ requested length + 5 min:
  1. one more set on the main lift with the fewest sets, up to the goal's cap (strength 5, muscle 4, fat loss 4, health 4, endurance 3, mobility 2; never below the prescribed sets);
  2. one accessory from the catalogue that the equipment, avoided list, limitations and age rules allow (favourites first; pool: calf raise, lateral raise, biceps curl, triceps pushdown, face pull, band pull-apart, superman, dead bug, bird dog, side plank, plank, single-leg balance);
  3. 5 more minutes of the cardio finisher, up to 15 min (finisher) or 30 min (dedicated), only when cardio was chosen.
- Each day that changed gets one note ("Dia N: para chegar mais perto dos X min pedidos, acrescentámos …"). The rationale's prescription line keeps the base sets.
- Exceptions: sessions of 20 min can still run to about 25 min because the fit keeps at least three exercises; a day can stay under 80% only when no accessory the equipment covers is left (for example bodyweight and dumbbells only, at 75–90 min).

### Warm-up and cool-down
- Each day has a 5-minute warm-up that depends on the day: full body (hip rotation, glute activation, unloaded squats), upper/push/pull (shoulders, thoracic rotation, light push-ups or bands), lower/legs (hip circles, leg swings, glute bridges), mobility (cat-cow, hip circles).
- Cool-down is optional and not estimated.

### Progression
- Double progression per exercise: "quando fizeres N reps em todas as séries, aumenta a carga cerca de 2–5% (ou ~2 kg)". Timed holds: "acrescenta 5 s ou dificulta o exercício".
- Block weeks: weeks 1 to N−1 are normal progression (one more rep per set than last week, up to the top of the range). The last week is a deload with about 40% fewer sets (sets × 0.6, rounded).
- The preview groups consecutive identical weeks (`blockPhases`): "Semanas 1–3: progressão normal. …" then "Semana 4: descarga. …" for 4 weeks; 6 and 8 weeks follow the same pattern.
- Rep ranges use one formatter (`repRangeText`): "8–12 repetições" / "8–12 reps", and a degenerate range reads as one number ("10 repetições" / "10 reps"). It is used by the rationale and the progression text.

### Cardio
- Finisher: 10 min (5 min in sessions under 30 min) at the end of each session.
- Dedicated: 20 min at the end of each session (10 min under 45 min). Type from the answer; running and HIIT become walking when impact is not allowed.

### Explanation ("Porque este plano")
The notes are deterministic facts: split and why, prescription, returning after a break, each substitution, time fit, cardio, impact and age decisions, circuits, dumbbell limit, and the progression rule. The on-device model may add one summary sentence, accepted only if it has no safety, technique or medical claim, no digit that is not in the facts, and is at most 300 characters.

## Limits and disclaimer

- Under 18: plans are not generated in v1. The wizard blocks the flow and explains why.
- No safety or medical certification. Pain means seeing a health professional. The app shows this note in the limitations step and in the plan preview.
- Exercise catalogue (v1): 34 exercises. Equipment choices with no matching exercise (for example cardio machines, which are not in the catalogue) simply add nothing to the plan. The wizard offers cardio by type instead.
- Dedicated cardio is a 20-minute finisher, not a separate cardio-only day. A cardio-only day would need a schema change for days without strength exercises.
- Exercise instructions (`exerciseGuides`) exist for the original 22 exercises. The 12 newer exercises show no step-by-step guide yet.
- Stored with the active plan: exercises, sets, reps, rest and weekdays (`plan_exercises`, `workout_days`), and `workout_plans.details` (schema v6, JSON from `PlanDetails`): block length and start day, warm-up per workout, rationale notes, warnings and the accepted on-device sentence. Progression text is derived from each exercise row by `progressionRule`, so it stays correct after an edit. Plans saved before v6 have no details and show a note instead.
- The block week shown in the app is counted from the day the plan was saved (`PlanDetails.blockPosition`); the last week is the deload week.
- Preferences are stored locally in `plan_preferences` (version 2 JSON). Version 1 JSON is migrated on read (`PlanPreferences.decode`).

## Code map

- `lib/features/workouts/domain/plan_preferences.dart`: answers, version 1 → 2 migration, value lists.
- `lib/features/workouts/domain/exercise_traits.dart`: equipment per exercise, joint loads, impact, timed and accessory flags, `limitationConflict`.
- `lib/features/workouts/domain/plan_generator.dart`: split, selection, prescription, time fit, block schedule, notes (`buildPlan`, `generatePlan` kept for version 1 callers).
- `lib/features/workouts/domain/ai_plan.dart`: rationale prompt and output check only.
- `lib/features/workouts/plan_wizard_page.dart`: the 14-step wizard and review.
- `lib/features/workouts/data/workout_repository.dart`: preferences load/save (mirrors goal, days, experience and equipment into the profile), catalogue, `rulePlan`.

## Tests

- `test/plan_preferences_test.dart`: migration from version 1 JSON, round-trip, bad values, under-18 flag.
- `test/plan_rules_test.dart`: split, substitutions, avoided and favourite exercises, impact, 60+, prescription and comeback, time fit, circuits, cardio, block and progression.
- `test/plan_constraints_test.dart`: 400 seeded random answer sets. Checks: day count, block structure, no duplicate exercise in a day, equipment covered, no avoided exercise, no limitation conflict, time within the tolerance, and a warning whenever a day has fewer than three exercises. Plus under-18 never generates.
- `test/plan_constraints_test.dart` (time fit): typical equipment sets, every goal and level, 1–6 days, 20–90 min. Each day stays within max(105%, request + 5 min), and any day under 80% must have no accessory left that the equipment covers.
- `test/plan_rules_test.dart`: rep formatter (degenerate and normal ranges), health rationale and progression never show "10–10", block grouping for 4/6/8 weeks in both languages, a 45 min beginner day in 80–105%, the set cap, and no padding past the tolerance.
- `test/plan_wizard_test.dart`: adaptive questions, skipping, equipment by place, dumbbell weight, under-18 block.
- `test/ai_plan_test.dart`: summary prompt and output check.
- `test/workout_plan_details_test.dart`: `PlanDetails` round-trip, block week and deload, damaged JSON, savePlan/export/import of the details.
- `test/app_database_migration_test.dart`: schema v5 → v6 (drift schema dumps in `drift_schemas/`, helpers in `test/generated_migrations/`).
