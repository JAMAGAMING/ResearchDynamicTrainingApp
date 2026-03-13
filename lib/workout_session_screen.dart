import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'training_plan_model.dart';
import 'plan_storage.dart';

// ─────────────────────────────────────────────
//  WorkoutSessionScreen
//
//  Interactive sequential checklist for a training day.
//
//  Step order (flat, strictly sequential):
//    [0]       Warm-up              (1 checkbox)
//    [1]       Run – set 1          (1 checkbox)
//    [2]       Walk – set 1         (1 checkbox)
//    [3]       Run – set 2          (1 checkbox)
//    [4]       Walk – set 2         (1 checkbox)
//    ...
//    [2N-1]    Run – set N          (1 checkbox)
//    [2N]      Walk – set N         (1 checkbox)
//    [2N+1]    Cool-down            (1 checkbox)
//    [2N+2]    Stretching           (1 checkbox)
//
//  Rules:
//  • Step i is tappable only when step i-1 is checked.
//  • Tapping a checked step unchecks it AND all steps after it.
//  • Tapping an unchecked, unlocked step starts its countdown timer.
//  • When the timer reaches 0:00 the alarm rings and the step is
//    auto-checked (except Stretching, which rings but waits for
//    the user to tap to confirm).
//  • Unchecking a step cancels and resets its timer.
//  • When all steps are checked → show completion dialog.
//
//  Dependencies (add to pubspec.yaml):
//    flutter_ringtone_player: ^4.0.0
// ─────────────────────────────────────────────

class WorkoutSessionScreen extends StatefulWidget {
  final DayWorkout workout;
  final DateTime   date;

  const WorkoutSessionScreen({
    super.key,
    required this.workout,
    required this.date,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late final List<_Step> _steps;
  late final List<bool>  _checked;

  // Timer state — at most one active timer at a time.
  int?   _activeIndex; // which step is currently timing
  int    _remaining = 0;
  bool   _isPaused  = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _steps   = _buildSteps(widget.workout);
    _checked = List.filled(_steps.length, false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Build flat sequential step list ──────────
  static List<_Step> _buildSteps(DayWorkout w) {
    final list = <_Step>[];

    list.add(_Step(
      type:         _T.warmup,
      label:        'Warm-up',
      detail:       '5:00 easy jog',
      timerSeconds: w.warmupSeconds,
    ));

    for (int i = 1; i <= w.sets; i++) {
      list.add(_Step(
        type:         _T.run,
        label:        'Run',
        detail:       w.runDisplay,
        setNum:       i,
        totalSets:    w.sets,
        timerSeconds: w.runSeconds,
      ));
      list.add(_Step(
        type:         _T.walk,
        label:        'Walk',
        detail:       '2:00',
        setNum:       i,
        totalSets:    w.sets,
        timerSeconds: w.walkSeconds,
      ));
    }

    list.add(_Step(
      type:         _T.cooldown,
      label:        'Cool-down',
      detail:       '5:00 easy jog',
      timerSeconds: w.cooldownSeconds,
    ));
    // Stretching: 5-min suggested timer, rings as nudge but does NOT auto-check.
    list.add(_Step(
      type:         _T.stretch,
      label:        'Stretching',
      detail:       '5–10 min',
      timerSeconds: 300,
    ));

    return list;
  }

  // ── State helpers ─────────────────────────────
  bool   get _allDone   => _checked.every((c) => c);
  int    get _doneCount => _checked.where((c) => c).length;
  double get _progress  => _steps.isEmpty ? 0.0 : _doneCount / _steps.length;

  bool _canCheck(int i) => i == 0 || _checked[i - 1];

  // ── Timer control ─────────────────────────────

  void _startTicker(int i) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _ticker?.cancel();
        _ticker = null;
        _onTimerFinished(i);
      }
    });
  }

  void _startTimer(int i) {
    _ticker?.cancel();
    setState(() {
      _activeIndex = i;
      _isPaused    = false;
      _remaining   = _steps[i].timerSeconds;
    });
    _startTicker(i);
  }

  void _pauseTimer() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _isPaused = true);
  }

  void _resumeTimer() {
    setState(() => _isPaused = false);
    _startTicker(_activeIndex!);
  }

  void _cancelTimer() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _activeIndex = null;
      _remaining   = 0;
      _isPaused    = false;
    });
  }

  void _onTimerFinished(int i) {
    FlutterRingtonePlayer().playAlarm(looping: false);

    final isStretch = _steps[i].type == _T.stretch;

    setState(() {
      _activeIndex = null;
      _remaining   = 0;
      _isPaused    = false;
      if (!isStretch) _checked[i] = true;
    });

    if (!isStretch && _allDone) {
      Future.delayed(const Duration(milliseconds: 350), _showCompletionDialog);
    }
  }

  // ── Body tap → start / pause / resume timer ───
  void _onBodyTap(int i) {
    if (!_canCheck(i) || _checked[i]) return;

    if (_activeIndex == i) {
      // This step's timer is running or paused — toggle pause.
      _isPaused ? _resumeTimer() : _pauseTimer();
      return;
    }

    // Another step's timer is running — cancel it, start this one.
    if (_activeIndex != null) _cancelTimer();
    _startTimer(i);
  }

  // ── Checkbox tap → manual mark complete / uncheck ──
  void _onCheckTap(int i) {
    if (!_canCheck(i) && !_checked[i]) return;

    if (_checked[i]) {
      // Un-check: cancel timer if it belongs to this step or later.
      if (_activeIndex != null && _activeIndex! >= i) _cancelTimer();
      setState(() {
        for (int j = i; j < _checked.length; j++) _checked[j] = false;
      });
      return;
    }

    // Manually mark complete — cancel this step's timer if running.
    if (_activeIndex == i) _cancelTimer();
    setState(() => _checked[i] = true);

    if (_allDone) {
      Future.delayed(const Duration(milliseconds: 350), _showCompletionDialog);
    }
  }

  // ── Persist completion ────────────────────────
  Future<void> _saveCompletion() async {
    final dateKey =
        '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

    final plan = await PlanStorage.loadActive();
    if (plan == null) return;

    final updatedWorkouts = Map<String, DayWorkout>.from(plan.workouts);
    final existing = updatedWorkouts[dateKey];
    if (existing != null) {
      updatedWorkouts[dateKey] = existing.copyWith(isCompleted: true);
    }

    final updatedPlan = TrainingPlan(
      id:        plan.id,
      profile:   plan.profile,
      startDate: plan.startDate,
      tim:       plan.tim,
      workouts:  updatedWorkouts,
    );

    await PlanStorage.save(updatedPlan);
  }

  // ── Completion dialog ─────────────────────────
  void _showCompletionDialog() {
    if (!mounted) return;
    _saveCompletion();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                    color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Workout Complete!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 8),
              const Text(
                'Great work. Rest up and come back stronger.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // close session screen
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date label ────────────────────────────────
  String get _dateLabel {
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = widget.date;
    return '${days[d.weekday - 1]}, ${months[d.month]} ${d.day}';
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Today's Workout",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _ProgressHeader(
            dateLabel:  _dateLabel,
            progress:   _progress,
            doneCount:  _doneCount,
            totalCount: _steps.length,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _steps.length,
              itemBuilder: (_, i) {
                final step      = _steps[i];
                final isChecked = _checked[i];
                final isLocked  = !_canCheck(i);
                final isTiming  = _activeIndex == i;
                final showSetHeader = step.type == _T.run;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSetHeader) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'Set ${step.setNum} of ${step.totalSets}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: isChecked
                                ? Colors.green.shade400
                                : isLocked
                                ? Colors.white24
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ] else if (step.type != _T.walk)
                      const SizedBox(height: 12),

                    _StepTile(
                      step:        step,
                      isChecked:   isChecked,
                      isLocked:    isLocked,
                      isTiming:    isTiming,
                      isPaused:    _isPaused && isTiming,
                      remaining:   isTiming ? _remaining : step.timerSeconds,
                      onBodyTap:   () => _onBodyTap(i),
                      onCheckTap:  () => _onCheckTap(i),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Progress Header
// ─────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final String dateLabel;
  final double progress;
  final int    doneCount;
  final int    totalCount;

  const _ProgressHeader({
    required this.dateLabel,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('$doneCount / $totalCount steps',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green.shade400 : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Step Tile  (includes countdown timer)
// ─────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final _Step        step;
  final bool         isChecked;
  final bool         isLocked;
  final bool         isTiming;    // countdown is actively running
  final bool         isPaused;    // timer exists but is paused
  final int          remaining;   // seconds to display (full duration if idle)
  final VoidCallback onBodyTap;   // start / pause / resume
  final VoidCallback onCheckTap;  // manual check / uncheck

  const _StepTile({
    required this.step,
    required this.isChecked,
    required this.isLocked,
    required this.isTiming,
    required this.isPaused,
    required this.remaining,
    required this.onBodyTap,
    required this.onCheckTap,
  });

  Color get _bg {
    if (isChecked) return Colors.green.shade400;
    if (isPaused) return Colors.grey.shade900;
    if (isTiming)  return Colors.blue.shade700.withOpacity(0.35);
    if (isLocked)  return Colors.white.withOpacity(0.04);
    return Colors.white.withOpacity(0.10);
  }

  Color get _border {
    if (isChecked) return Colors.green.shade400;
    if (isPaused) return Colors.grey.withOpacity(0.45);
    if (isTiming)  return Colors.blue.shade300;
    if (isLocked)  return Colors.white12;
    return Colors.white24;
  }

  Color get _textColor =>
      (isLocked && !isChecked) ? Colors.white24 : Colors.white;

  Color get _subColor {
    if (isChecked) return Colors.white70;
    if (isLocked)  return Colors.white12;
    return Colors.white54;
  }

  IconData get _icon {
    switch (step.type) {
      case _T.warmup:   return Icons.self_improvement;
      case _T.run:      return Icons.directions_run;
      case _T.walk:     return Icons.directions_walk;
      case _T.cooldown: return Icons.air;
      case _T.stretch:  return Icons.accessibility_new;
    }
  }

  static String _fmt(int s) {
    final m   = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timerFraction = step.timerSeconds > 0
        ? (remaining / step.timerSeconds).clamp(0.0, 1.0)
        : 0.0;

    final timerColor = (isTiming && remaining <= 10)
        ? Colors.red.shade300
        : Colors.white70;

    // Checkbox icon — always a plain check or lock, never changes for timer state
    Widget? checkIcon;
    if (isChecked) {
      checkIcon = const Icon(Icons.check, size: 15, color: Colors.black);
    } else if (isLocked) {
      checkIcon = const Icon(Icons.lock_outline, size: 13, color: Colors.white12);
    }

    return GestureDetector(
      // Body tap → timer start / pause / resume
      onTap: isLocked ? null : onBodyTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Main row ───────────────────────────
            Row(
              children: [
                Icon(_icon, size: 20, color: _textColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textColor)),
                      Text(step.detail,
                          style: TextStyle(fontSize: 12, color: _subColor)),
                    ],
                  ),
                ),

                // ── Timer readout ──────────────────
                if (!isChecked) ...[
                  Text(
                    _fmt(remaining),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isTiming ? timerColor : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // ── Checkbox (separate tap zone) ───
                GestureDetector(
                  onTap: isLocked ? null : onCheckTap,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isChecked ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChecked
                            ? Colors.white
                            : isLocked
                            ? Colors.white12
                            : Colors.white54,
                        width: 2,
                      ),
                    ),
                    child: checkIcon,
                  ),
                ),
              ],
            ),

            // ── Progress bar (while timing or paused) ──
            if (isTiming || isPaused) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: timerFraction,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPaused ? Colors.white38 : timerColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Data types
// ─────────────────────────────────────────────

enum _T { warmup, run, walk, cooldown, stretch }

class _Step {
  final _T     type;
  final String label;
  final String detail;
  final int    timerSeconds; // full countdown duration
  final int?   setNum;
  final int?   totalSets;

  const _Step({
    required this.type,
    required this.label,
    required this.detail,
    required this.timerSeconds,
    this.setNum,
    this.totalSets,
  });
}