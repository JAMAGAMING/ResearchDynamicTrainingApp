import 'dart:convert';
import 'dart:math';

// ─────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────

enum AgeGroup { teen, adult, elder }
enum ExperienceLevel { beginner, intermediate, experienced }
enum CalorieIntake { deficit, maintenance, surplus }
enum BodyType { ectomorph, mesomorph, endomorph }

// ─────────────────────────────────────────────
//  BodyMetrics
// ─────────────────────────────────────────────

class BodyMetrics {
  final double weightKg;
  final double heightCm;

  const BodyMetrics({required this.weightKg, required this.heightCm});

  double get bmi {
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  BodyType get bodyType {
    final b = bmi;
    if (b < 18.5) return BodyType.ectomorph;
    if (b < 25.0) return BodyType.mesomorph;
    return BodyType.endomorph;
  }

  CalorieIntake get recommendedCalorieIntake {
    switch (bodyType) {
      case BodyType.ectomorph: return CalorieIntake.surplus;
      case BodyType.mesomorph: return CalorieIntake.maintenance;
      case BodyType.endomorph: return CalorieIntake.deficit;
    }
  }

  String get bodyTypeLabel {
    switch (bodyType) {
      case BodyType.ectomorph: return 'Ectomorph';
      case BodyType.mesomorph: return 'Mesomorph';
      case BodyType.endomorph: return 'Endomorph';
    }
  }

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'heightCm': heightCm,
  };

  factory BodyMetrics.fromJson(Map<String, dynamic> j) => BodyMetrics(
    weightKg: (j['weightKg'] as num).toDouble(),
    heightCm: (j['heightCm'] as num).toDouble(),
  );
}

// ─────────────────────────────────────────────
//  UserProfile
// ─────────────────────────────────────────────

class UserProfile {
  final String name;
  final AgeGroup ageGroup;
  final ExperienceLevel experienceLevel;
  final BodyMetrics metrics;
  final CalorieIntake calorieIntake;

  const UserProfile({
    required this.name,
    required this.ageGroup,
    required this.experienceLevel,
    required this.metrics,
    required this.calorieIntake,
  });

  BodyType get bodyType => metrics.bodyType;

  Map<String, dynamic> toJson() => {
    'name': name,
    'ageGroup': ageGroup.index,
    'experienceLevel': experienceLevel.index,
    'metrics': metrics.toJson(),
    'calorieIntake': calorieIntake.index,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'],
    ageGroup: AgeGroup.values[j['ageGroup']],
    experienceLevel: ExperienceLevel.values[j['experienceLevel']],
    metrics: BodyMetrics.fromJson(j['metrics']),
    calorieIntake: CalorieIntake.values[j['calorieIntake']],
  );
}

// ─────────────────────────────────────────────
//  DayWorkout
// ─────────────────────────────────────────────

class DayWorkout {
  final bool isRest;
  final bool isRecreational;
  final bool isUnavailable; // user-marked: grayed out, workout moved elsewhere
  final bool isCompleted;   // user finished all steps of this training day
  final int warmupSeconds;
  final int runSeconds;
  final int walkSeconds;
  final int sets;
  final int cooldownSeconds;

  /// Which training slot this day belongs to:
  ///   0 = short run  (min 30s)
  ///   1 = medium run (min 60s)
  ///   2 = long run   (min 90s)
  ///  -1 = not a training day (rest / recreational / unavailable)
  final int slotIndex;

  const DayWorkout({
    this.isRest = false,
    this.isRecreational = false,
    this.isUnavailable = false,
    this.isCompleted = false,
    this.warmupSeconds = 300,
    required this.runSeconds,
    this.walkSeconds = 120,
    required this.sets,
    this.cooldownSeconds = 300,
    this.slotIndex = -1,
  });

  /// Minimum run seconds enforced for each slot.
  static const slotMinSeconds = [30, 60, 90];

  /// Returns the minimum run duration for this day's slot,
  /// or 30 as a safe fallback for unknown training days.
  int get minRunSeconds {
    if (slotIndex >= 0 && slotIndex < slotMinSeconds.length) {
      return slotMinSeconds[slotIndex];
    }
    return 30;
  }

  String get runDisplay {
    final m = runSeconds ~/ 60;
    final s = runSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get walkDisplay     => '2:00';
  String get warmupDisplay   => '5:00';
  String get cooldownDisplay => '5:00';

  List<String> get exerciseList {
    if (isUnavailable)  return ['Unavailable – workout moved to another day'];
    if (isRecreational) return ['Rest or light recreational activity (walk, stretching, yoga)'];
    if (isRest)         return ['Rest Day – recover and hydrate'];
    return [
      'Warm-up: 5:00 easy jog',
      for (int i = 1; i <= sets; i++) ...[
        'Set $i – Run: $runDisplay at training pace',
        if (i < sets) 'Set $i – Walk: $walkDisplay recovery',
      ],
      'Cool-down: 5:00 easy jog',
      'Stretching: 5–10 min',
    ];
  }

  Map<String, dynamic> toJson() => {
    'isRest': isRest,
    'isRecreational': isRecreational,
    'isUnavailable': isUnavailable,
    'isCompleted': isCompleted,
    'warmupSeconds': warmupSeconds,
    'runSeconds': runSeconds,
    'walkSeconds': walkSeconds,
    'sets': sets,
    'cooldownSeconds': cooldownSeconds,
    'slotIndex': slotIndex,
  };

  factory DayWorkout.fromJson(Map<String, dynamic> j) => DayWorkout(
    isRest: j['isRest'],
    isRecreational: j['isRecreational'] ?? false,
    isUnavailable: j['isUnavailable'] ?? false,
    isCompleted: j['isCompleted'] ?? false,
    warmupSeconds: j['warmupSeconds'],
    runSeconds: j['runSeconds'],
    walkSeconds: j['walkSeconds'],
    sets: j['sets'],
    cooldownSeconds: j['cooldownSeconds'],
    slotIndex: (j['slotIndex'] as int?) ?? -1,
  );

  static DayWorkout rest()         => const DayWorkout(isRest: true, runSeconds: 0, sets: 0);
  static DayWorkout recreational() => const DayWorkout(isRest: true, isRecreational: true, runSeconds: 0, sets: 0);
  static DayWorkout unavailable()  => const DayWorkout(isUnavailable: true, isRest: false, runSeconds: 0, sets: 0);

  DayWorkout copyWith({bool? isUnavailable, bool? isCompleted, int? runSeconds, int? sets}) => DayWorkout(
    isRest:         isRest,
    isRecreational: isRecreational,
    isUnavailable:  isUnavailable ?? this.isUnavailable,
    isCompleted:    isCompleted   ?? this.isCompleted,
    warmupSeconds:  warmupSeconds,
    runSeconds:     runSeconds    ?? this.runSeconds,
    walkSeconds:    walkSeconds,
    sets:           sets          ?? this.sets,
    cooldownSeconds: cooldownSeconds,
    slotIndex:      slotIndex,
  );
}

// ─────────────────────────────────────────────
//  TrainingPlan — now has a unique id
// ─────────────────────────────────────────────

class TrainingPlan {
  final String id;           // unique — used for storage & selection
  final UserProfile profile;
  final DateTime startDate;
  final double tim;
  final Map<String, DayWorkout> workouts;

  /// Cumulative seconds added/subtracted from every training day's runSeconds.
  /// Applied on top of the generator's original values. Default 0.
  final int intensityDeltaSeconds;

  /// Cumulative sets added/subtracted from every training day.
  /// Applied on top of the generator's original values. Default 0.
  final int setsDelta;

  const TrainingPlan({
    required this.id,
    required this.profile,
    required this.startDate,
    required this.tim,
    required this.workouts,
    this.intensityDeltaSeconds = 0,
    this.setsDelta             = 0,
  });

  DayWorkout? getWorkoutForDate(DateTime date) => workouts[_dateKey(date)];

  /// Human-readable label shown in the plan list
  String get displayName => profile.name;

  String get summaryLine {
    final d = startDate;
    return 'Started ${d.day}/${d.month}/${d.year}  •  TIM ${tim.toStringAsFixed(2)}';
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profile.toJson(),
    'startDate': startDate.toIso8601String(),
    'tim': tim,
    'workouts': workouts.map((k, v) => MapEntry(k, v.toJson())),
    'intensityDeltaSeconds': intensityDeltaSeconds,
    'setsDelta':             setsDelta,
  };

  factory TrainingPlan.fromJson(Map<String, dynamic> j) => TrainingPlan(
    id:                     j['id'] as String,
    profile:                UserProfile.fromJson(j['profile']),
    startDate:              DateTime.parse(j['startDate']),
    tim:                    (j['tim'] as num).toDouble(),
    workouts:               (j['workouts'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, DayWorkout.fromJson(v as Map<String, dynamic>))),
    intensityDeltaSeconds:  (j['intensityDeltaSeconds'] as int?) ?? 0,
    setsDelta:              (j['setsDelta']             as int?) ?? 0,
  );

  String toJsonString()                        => jsonEncode(toJson());
  static TrainingPlan fromJsonString(String s) => TrainingPlan.fromJson(jsonDecode(s));

  // ─────────────────────────────────────────────
  //  extendPlan
  //
  //  Appends 28 new days to this plan.
  //
  //  The extension starts the day AFTER the last
  //  existing date in the workouts map.
  //
  //  Training templates are lifted directly from
  //  the existing plan's workouts so any intensity
  //  adjustments are automatically preserved.
  //  The 7-day cycle is:
  //    0 → short run  (same as existing day-0 template)
  //    1 → rest
  //    2 → medium run (same as existing day-2 template)
  //    3 → rest
  //    4 → long run   (same as existing day-4 template)
  //    5 → rest
  //    6 → recreational
  //
  //  None of the new days are marked completed.
  // ─────────────────────────────────────────────

  TrainingPlan extendPlan() {
    // 1. Find the last date currently in the plan.
    final sortedDates = workouts.keys.map(DateTime.parse).toList()..sort();
    final lastDate    = sortedDates.last;

    // 2. Extract the 3 training templates from existing workouts.
    //    Look up by slotIndex (0=easy, 1=medium, 2=hard) so that a previously
    //    rescheduled plan whose training days are no longer in chronological
    //    slot order still produces templates in the correct difficulty sequence.
    //    Walk chronologically and keep the first occurrence of each slotIndex.
    final templateBySlotMap = <int, DayWorkout>{};
    for (final date in sortedDates) {
      final w = workouts[_dateKey(date)]!;
      if (!w.isRest && !w.isRecreational && !w.isUnavailable && w.slotIndex >= 0) {
        templateBySlotMap.putIfAbsent(w.slotIndex, () => w);
        if (templateBySlotMap.length == 3) break;
      }
    }
    // Build ordered list [slot0, slot1, slot2] for the cycle below.
    final templates = [
      templateBySlotMap[0],
      templateBySlotMap[1],
      templateBySlotMap[2],
    ];

    // Fallback: if a slot was not found in the live plan, synthesise from
    // the generator baseline so intensity deltas are still respected.
    const fallbackRun  = [60, 90, 120];
    const fallbackSets = [6, 5, 6];
    final resolvedTemplates = List<DayWorkout>.generate(3, (idx) {
      return templates[idx] ?? DayWorkout(
        runSeconds: (fallbackRun[idx]  + intensityDeltaSeconds).clamp(30, 600),
        sets:       (fallbackSets[idx] + setsDelta).clamp(1, 12),
        slotIndex:  idx,
      );
    });

    // Template index by cycle position:  0→short, 2→medium, 4→long
    final templateBySlot = {
      0: resolvedTemplates[0],
      2: resolvedTemplates[1],
      4: resolvedTemplates[2],
    };

    // 3. Stamp out 28 new days starting the day after lastDate.
    final extended = Map<String, DayWorkout>.from(workouts);

    for (int i = 0; i < 28; i++) {
      final date       = lastDate.add(Duration(days: i + 1));
      final dayInCycle = i % 7;
      final key        = _dateKey(date);

      if (templateBySlot.containsKey(dayInCycle)) {
        final t = templateBySlot[dayInCycle]!;
        extended[key] = DayWorkout(
          runSeconds:      t.runSeconds,
          sets:            t.sets,
          warmupSeconds:   t.warmupSeconds,
          walkSeconds:     t.walkSeconds,
          cooldownSeconds: t.cooldownSeconds,
          slotIndex:       t.slotIndex,
          // isCompleted defaults to false — new days are not done yet
        );
      } else if (dayInCycle == 6) {
        extended[key] = DayWorkout.recreational();
      } else {
        extended[key] = DayWorkout.rest();
      }
    }

    return TrainingPlan(
      id:                    id,
      profile:               profile,
      startDate:             startDate,
      tim:                   tim,
      workouts:              extended,
      intensityDeltaSeconds: intensityDeltaSeconds,
      setsDelta:             setsDelta,
    );
  }
}

// ─────────────────────────────────────────────
//  TrainingPlanGenerator
// ─────────────────────────────────────────────

class TrainingPlanGenerator {
  static const int _maxSetIncrease = 2;

  static double _ageFactor(AgeGroup a) =>
      a == AgeGroup.teen ? 1.30 : a == AgeGroup.adult ? 1.00 : 0.65;

  static double _expFactor(ExperienceLevel e) =>
      e == ExperienceLevel.beginner ? 0.70 : e == ExperienceLevel.intermediate ? 1.00 : 1.25;

  static double _calFactor(CalorieIntake c) =>
      c == CalorieIntake.deficit ? 0.80 : c == CalorieIntake.maintenance ? 1.00 : 1.20;

  static double _bodyFactor(BodyType b) =>
      b == BodyType.ectomorph ? 1.15 : b == BodyType.mesomorph ? 1.00 : 0.90;

  static double computeTIM(UserProfile p) {
    final raw = (_ageFactor(p.ageGroup)       * 0.40) +
        (_expFactor(p.experienceLevel) * 0.30) +
        (_calFactor(p.calorieIntake)   * 0.20) +
        (_bodyFactor(p.bodyType)        * 0.10);
    return raw.clamp(0.65, 1.45);
  }

  static int _adjustedRun(int baseSeconds, double tim) {
    final adjustment = ((tim - 1.0) * 120).clamp(-60.0, 60.0);
    return (((baseSeconds + adjustment) / 10).ceil() * 10).toInt();
  }

  static int _adjustedSets(int baseSets, double tim) {
    final sam = ((tim - 1.0) * _maxSetIncrease).floor();
    return (baseSets + sam).clamp(baseSets, baseSets + _maxSetIncrease);
  }

  static String _generateId() {
    final now    = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return '${now.millisecondsSinceEpoch}_$random';
  }

  static TrainingPlan generate(UserProfile profile, DateTime startDate) {
    final tim      = computeTIM(profile);
    final workouts = <String, DayWorkout>{};

    // Pattern repeats every 7 days regardless of which weekday startDate falls on:
    // Day 0 → Train (short)   runBase=60s  sets=6
    // Day 1 → Rest
    // Day 2 → Train (medium)  runBase=90s  sets=5
    // Day 3 → Rest
    // Day 4 → Train (long)    runBase=120s sets=6
    // Day 5 → Rest
    // Day 6 → Recreational (light rest)
    const patternRun  = {0: 60,  2: 90,  4: 120};
    const patternSets = {0: 6,   2: 5,   4: 6};

    // Slot index by cycle position: 0→short(0), 2→medium(1), 4→long(2)
    const patternSlot = {0: 0,   2: 1,   4: 2};

    for (int i = 0; i < 28; i++) {
      final date       = startDate.add(Duration(days: i));
      final dayInCycle = i % 7;
      final key        = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      if (patternRun.containsKey(dayInCycle)) {
        workouts[key] = DayWorkout(
          runSeconds: _adjustedRun(patternRun[dayInCycle]!, tim),
          sets:       _adjustedSets(patternSets[dayInCycle]!, tim),
          slotIndex:  patternSlot[dayInCycle]!,
        );
      } else if (dayInCycle == 6) {
        workouts[key] = DayWorkout.recreational();
      } else {
        workouts[key] = DayWorkout.rest();
      }
    }

    return TrainingPlan(
      id:        _generateId(),
      profile:   profile,
      startDate: startDate,
      tim:       tim,
      workouts:  workouts,
    );
  }
}

// ─────────────────────────────────────────────
//  UnavailableScheduler
//
//  Core placement rules:
//  • Every placed training session reserves the
//    NEXT day as a forced rest slot.
//  • A day can only be a training landing target
//    if it is NOT occupied AND NOT a forced rest
//    slot of an already-placed session.
//  • If the day AFTER the chosen target is already
//    occupied by training, that training is bumped
//    forward (cascade) before we finalize.
//  • Search is FORWARD ONLY from the original date.
//  • Plan extends past 28 days if needed.
//
//  Recreational rule:
//  • Training sessions are counted in groups of 3.
//  • After every COMPLETE uninterrupted group of 3
//    training days, a recreational day is inserted
//    immediately after the trailing rest day.
//  • "Uninterrupted" means no unavailable day falls
//    within that group of 3.
//  • A broken group resets the counter — the next
//    recreational day only comes after the next
//    clean group of 3 completes.
//
//  Pattern examples:
//  Normal:
//    T→rest→T→rest→T→rest→recreational
//  1 unavailable (group broken):
//    X→T→rest→X→T→rest→T→rest→T→rest→recreational
//  3 unavailable:
//    X→X→X→T→rest→X→T→rest→T→rest→T→rest→recreational
// ─────────────────────────────────────────────

class UnavailableScheduler {
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, DayWorkout> reschedule(
      Map<String, DayWorkout> base,
      Set<String> unavailableKeys,
      ) {
    final result    = Map<String, DayWorkout>.from(base);
    final baseDates = base.keys.map(DateTime.parse).toList()..sort();

    // ── Step 1: Collect displaced workouts in chronological order ──
    final queue = <({DateTime origin, DayWorkout workout})>[];

    for (final date in baseDates) {
      final k = _key(date);
      if (unavailableKeys.contains(k)) {
        final w = base[k]!;
        if (!w.isRest && !w.isUnavailable) {
          queue.add((origin: date, workout: w));
        }
        result[k] = DayWorkout.unavailable();
      }
    }

    // ── Step 2: Build initial occupied + restAfter sets ──
    final occupied  = <String>{};
    final restAfter = <String>{};

    for (final date in baseDates) {
      final k = _key(date);
      final w = result[k]!;
      if (!w.isRest && !w.isUnavailable) {
        occupied.add(k);
        restAfter.add(_key(date.add(const Duration(days: 1))));
      }
    }

    // ── Step 3: Place each displaced workout forward-only ──
    final mutableQueue = List.of(queue);

    while (mutableQueue.isNotEmpty) {
      final item    = mutableQueue.removeAt(0);
      final origin  = item.origin;
      final workout = item.workout;

      DateTime? target;
      for (int offset = 1; offset <= 90 && target == null; offset++) {
        final candidate = origin.add(Duration(days: offset));
        final ck        = _key(candidate);

        if (unavailableKeys.contains(ck)) continue;
        if (occupied.contains(ck))        continue;
        if (restAfter.contains(ck))       continue;

        target = candidate;
      }

      if (target == null) continue;

      final tk      = _key(target);
      final nextDay = target.add(const Duration(days: 1));
      final nk      = _key(nextDay);

      // If the day after target is already a training session,
      // bump it forward. Use base[nk] to avoid reading a mutated entry.
      if (occupied.contains(nk)) {
        final bumpedWorkout = base[nk] ?? result[nk];
        if (bumpedWorkout != null &&
            !bumpedWorkout.isRest &&
            !bumpedWorkout.isUnavailable) {
          mutableQueue.insert(0, (origin: nextDay, workout: bumpedWorkout));
          occupied.remove(nk);
          restAfter.remove(_key(nextDay.add(const Duration(days: 1))));
          result[nk] = DayWorkout.rest();
        }
      }

      // Place the workout, preserving all fields including isCompleted and slotIndex.
      result[tk] = DayWorkout(
        runSeconds:      workout.runSeconds,
        sets:            workout.sets,
        warmupSeconds:   workout.warmupSeconds,
        walkSeconds:     workout.walkSeconds,
        cooldownSeconds: workout.cooldownSeconds,
        isCompleted:     workout.isCompleted,
        slotIndex:       workout.slotIndex,
      );
      occupied.add(tk);

      restAfter.add(nk);
      result.putIfAbsent(nk, () => DayWorkout.rest());
      if (!result[nk]!.isUnavailable && !occupied.contains(nk)) {
        result[nk] = DayWorkout.rest();
      }
    }

    // ── Step 4: Recompute recreational days ──────────────────────────────
    //
    // Strip all existing recreational markers — we recompute from scratch.
    for (final k in result.keys.toList()) {
      if (result[k]!.isRecreational) result[k] = DayWorkout.rest();
    }

    // Walk the full sorted timeline. Count training days in groups of 3.
    // A group is "clean" if no unavailable day appeared within it (between
    // the start of that group and the 3rd training day, inclusive).
    // After a clean group of 3, the day two slots after the 3rd training day
    // (i.e. rest-day + 1) becomes recreational.
    // An unavailable day taints the current group, resetting cleanness but
    // NOT the counter — the counter resets only when a group of 3 completes.
    final allDates      = result.keys.map(DateTime.parse).toList()..sort();
    int  trainingCount  = 0; // within current group of 3
    bool groupClean     = true;

    for (int i = 0; i < allDates.length; i++) {
      final date = allDates[i];
      final k    = _key(date);
      final w    = result[k]!;

      if (w.isUnavailable) {
        groupClean = false;
        continue;
      }

      if (w.isRest) continue;

      // Training day.
      trainingCount++;

      if (trainingCount == 3) {
        if (groupClean) {
          // Recreational slot = training day + 2 (skip the mandatory rest day).
          final recDate = date.add(const Duration(days: 2));
          final rek     = _key(recDate);

          // Only mark recreational if the slot is a plain rest day
          // (not a training session or unavailable).
          result.putIfAbsent(rek, () => DayWorkout.rest());
          final slot = result[rek]!;
          if (slot.isRest && !slot.isUnavailable && !occupied.contains(rek)) {
            result[rek] = DayWorkout.recreational();
          }
        }

        // Reset for the next group.
        trainingCount = 0;
        groupClean    = true;
      }
    }

    return result;
  }
}