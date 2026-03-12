import 'package:flutter/material.dart';
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
//  • When all steps are checked → show completion dialog.
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

  @override
  void initState() {
    super.initState();
    _steps   = _buildSteps(widget.workout);
    _checked = List.filled(_steps.length, false);
  }

  // ── Build flat sequential step list ──────────
  static List<_Step> _buildSteps(DayWorkout w) {
    final list = <_Step>[];

    list.add(_Step(type: _T.warmup,   label: 'Warm-up',    detail: '5:00 easy jog'));

    for (int i = 1; i <= w.sets; i++) {
      list.add(_Step(type: _T.run,  label: 'Run',  detail: w.runDisplay, setNum: i, totalSets: w.sets));
      list.add(_Step(type: _T.walk, label: 'Walk', detail: '2:00',       setNum: i, totalSets: w.sets));
    }

    list.add(_Step(type: _T.cooldown, label: 'Cool-down',  detail: '5:00 easy jog'));
    list.add(_Step(type: _T.stretch,  label: 'Stretching', detail: '5–10 min'));

    return list;
  }

  // ── State helpers ─────────────────────────────
  bool   get _allDone   => _checked.every((c) => c);
  int    get _doneCount => _checked.where((c) => c).length;
  double get _progress  => _steps.isEmpty ? 0.0 : _doneCount / _steps.length;

  bool _canCheck(int i) => i == 0 || _checked[i - 1];

  void _toggle(int i) {
    if (!_canCheck(i) && !_checked[i]) return;
    setState(() {
      if (_checked[i]) {
        for (int j = i; j < _checked.length; j++) _checked[j] = false;
      } else {
        _checked[i] = true;
      }
    });
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
    // Persist completion to the saved plan
    _saveCompletion();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Workout Complete!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // close session screen
                  },
                  child: const Text('Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
                                : isLocked ? Colors.white24 : Colors.white54,
                          ),
                        ),
                      ),
                    ] else if (step.type != _T.walk)
                      const SizedBox(height: 12),

                    _StepTile(
                      step:      step,
                      isChecked: isChecked,
                      isLocked:  isLocked,
                      onTap:     () => _toggle(i),
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
//  Step Tile
// ─────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final _Step        step;
  final bool         isChecked;
  final bool         isLocked;
  final VoidCallback onTap;

  const _StepTile({
    required this.step,
    required this.isChecked,
    required this.isLocked,
    required this.onTap,
  });

  Color get _bg {
    if (isChecked) return Colors.green.shade400;
    if (isLocked)  return Colors.white.withOpacity(0.04);
    return Colors.white.withOpacity(0.10);
  }

  Color get _border {
    if (isChecked) return Colors.green.shade400;
    if (isLocked)  return Colors.white12;
    return Colors.white24;
  }

  Color get _textColor => (isLocked && !isChecked) ? Colors.white24 : Colors.white;
  Color get _subColor  {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: _textColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: _textColor)),
                  Text(step.detail,
                      style: TextStyle(fontSize: 12, color: _subColor)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: isChecked ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChecked ? Colors.white : isLocked ? Colors.white12 : Colors.white54,
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 15, color: Colors.black)
                  : isLocked
                  ? const Icon(Icons.lock_outline, size: 13, color: Colors.white12)
                  : null,
            ),
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
  final int?   setNum;
  final int?   totalSets;

  const _Step({
    required this.type,
    required this.label,
    required this.detail,
    this.setNum,
    this.totalSets,
  });
}