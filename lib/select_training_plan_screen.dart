import 'package:flutter/material.dart';
import 'training_plan_model.dart';
import 'plan_storage.dart';

// ─────────────────────────────────────────────
//  SelectTrainingPlanScreen
// ─────────────────────────────────────────────

class SelectTrainingPlanScreen extends StatefulWidget {
  final String? activePlanId;

  const SelectTrainingPlanScreen({super.key, this.activePlanId});

  @override
  State<SelectTrainingPlanScreen> createState() =>
      _SelectTrainingPlanScreenState();
}

class _SelectTrainingPlanScreenState
    extends State<SelectTrainingPlanScreen> {
  List<TrainingPlan> _plans   = [];
  String?            _activeId;
  bool               _loading = true;

  @override
  void initState() {
    super.initState();
    _activeId = widget.activePlanId;
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans  = await PlanStorage.loadAll();
    final active = await PlanStorage.loadActive();
    setState(() {
      _plans    = plans;
      _activeId = active?.id ?? _activeId;
      _loading  = false;
    });
  }

  Future<void> _selectPlan(TrainingPlan plan) async {
    await PlanStorage.setActive(plan.id);
    setState(() => _activeId = plan.id);
    if (!mounted) return;
    Navigator.pop(context, plan);
  }

  Future<void> _deletePlan(TrainingPlan plan) async {
    final confirm = await _showDeleteConfirm(plan.displayName);
    if (!confirm) return;
    await PlanStorage.delete(plan.id);
    final wasActive = plan.id == _activeId;
    await _loadPlans();
    if (wasActive && mounted) {
      final newActive = await PlanStorage.loadActive();
      if (!mounted) return;
      Navigator.pop(context, newActive);
    }
  }

  Future<bool> _showDeleteConfirm(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ── Adjust Intensity Dialog ───────────────

  Future<void> _showAdjustIntensity(TrainingPlan plan) async {
    // Close the modify bottom sheet first
    Navigator.pop(context);

    final updated = await showDialog<TrainingPlan>(
      context: context,
      builder: (_) => _AdjustIntensityDialog(plan: plan),
    );

    if (updated != null) {
      await _loadPlans();
      if (updated.id == _activeId && mounted) {
        Navigator.pop(context, updated);
      }
    }
  }

  // ── Edit Specific Days Dialog ────────────

  Future<void> _showEditSpecificDays(TrainingPlan plan) async {
    Navigator.pop(context); // close bottom sheet
    final updated = await showDialog<TrainingPlan>(
      context: context,
      builder: (_) => _EditSpecificDaysDialog(plan: plan),
    );
    if (updated != null) {
      await _loadPlans();
      if (updated.id == _activeId && mounted) {
        Navigator.pop(context, updated);
      }
    }
  }

  // ── Modify bottom sheet ───────────────────

  void _showModifyOptions(TrainingPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.displayName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            Text(plan.summaryLine,
                style:
                const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 20),
            _modifyTile(
              icon: Icons.tune,
              label: 'Adjust Intensity',
              subtitle: 'Change run duration & sets per day',
              onTap: () => _showAdjustIntensity(plan),
            ),
            const SizedBox(height: 10),
            _modifyTile(
              icon: Icons.edit_calendar,
              label: 'Edit Specific Days',
              subtitle: 'Mark days as unavailable — workout moves automatically',
              onTap: () => _showEditSpecificDays(plan),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _modifyTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Training Plans',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.white))
          : _plans.isEmpty
          ? _emptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        separatorBuilder: (_, __) =>
        const SizedBox(height: 12),
        itemBuilder: (_, i) => _planCard(_plans[i]),
      ),
    );
  }

  Widget _planCard(TrainingPlan plan) {
    final isActive = plan.id == _activeId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: Colors.black, width: 2.5)
            : null,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _selectPlan(plan),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 12),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.black
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(plan.displayName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black)),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: const Text('ACTIVE',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.8)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(plan.summaryLine,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                        const SizedBox(height: 6),
                        _statChips(plan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showModifyOptions(plan),
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: Colors.black54),
                    label: const Text('Modify',
                        style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.shade200),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deletePlan(plan),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChips(TrainingPlan plan) {
    final p = plan.profile;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _chip(_ageLabel(p.ageGroup)),
        _chip(_expLabel(p.experienceLevel)),
        _chip(_bodyTypeLabel(p.bodyType)),
        _chip(_calLabel(p.calorieIntake)),
      ],
    );
  }

  Widget _chip(String label) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text(label,
        style:
        const TextStyle(fontSize: 11, color: Colors.black54)),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fitness_center, size: 56, color: Colors.white24),
        const SizedBox(height: 16),
        const Text('No training plans yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Create one from the home screen',
            style: TextStyle(fontSize: 13, color: Colors.white54)),
      ],
    ),
  );

  String _ageLabel(AgeGroup a) {
    switch (a) {
      case AgeGroup.teen:  return 'Teen';
      case AgeGroup.adult: return 'Adult';
      case AgeGroup.elder: return 'Elder';
    }
  }

  String _expLabel(ExperienceLevel e) {
    switch (e) {
      case ExperienceLevel.beginner:     return 'Beginner';
      case ExperienceLevel.intermediate: return 'Intermediate';
      case ExperienceLevel.experienced:  return 'Experienced';
    }
  }

  String _bodyTypeLabel(BodyType b) {
    switch (b) {
      case BodyType.ectomorph: return 'Ectomorph';
      case BodyType.mesomorph: return 'Mesomorph';
      case BodyType.endomorph: return 'Endomorph';
    }
  }

  String _calLabel(CalorieIntake c) {
    switch (c) {
      case CalorieIntake.deficit:     return 'Deficit';
      case CalorieIntake.maintenance: return 'Maintenance';
      case CalorieIntake.surplus:     return 'Surplus';
    }
  }
}

// ─────────────────────────────────────────────
//  _AdjustIntensityDialog — single unified popup
//
//  Lower / Higher buttons shift ALL training day
//  run durations by ±30% from the plan's original
//  generated values, rounded to nearest 10s.
//  Sets stepper applies to all days equally.
// ─────────────────────────────────────────────

class _AdjustIntensityDialog extends StatefulWidget {
  final TrainingPlan plan;
  const _AdjustIntensityDialog({required this.plan});

  @override
  State<_AdjustIntensityDialog> createState() =>
      _AdjustIntensityDialogState();
}

class _AdjustIntensityDialogState
    extends State<_AdjustIntensityDialog> {
  static const _trainingDays = [1, 3, 5];
  static const _minSets      = 1;
  static const _maxSets      = 12;
  static const _step         = 0.30; // 30% per tap

  // Original run seconds per weekday, read once from plan
  late final Map<int, int> _originalRun;

  // Current intensity multiplier (1.0 = original, 1.3 = +30%, 0.7 = -30%)
  double _multiplier = 1.0;

  // Single sets value applied to all training days
  late int _sets;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _originalRun = {};
    int? firstSets;

    final sorted = widget.plan.workouts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sorted) {
      final date    = DateTime.parse(entry.key);
      final wd      = date.weekday;
      final workout = entry.value;

      if (_trainingDays.contains(wd) &&
          !workout.isRest &&
          !_originalRun.containsKey(wd)) {
        _originalRun[wd] = workout.runSeconds;
        firstSets ??= workout.sets;
      }
    }

    // Fallback
    for (final wd in _trainingDays) {
      _originalRun.putIfAbsent(wd, () => 60);
    }
    _sets = firstSets ?? 6;
  }

  // Round to nearest 10 seconds
  int _rounded(double raw) => ((raw / 10).round() * 10).clamp(10, 600);

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Human-readable level label
  String get _levelLabel {
    if (_multiplier >= 1.60) return 'Very High';
    if (_multiplier >= 1.30) return 'High';
    if (_multiplier >= 1.0)  return 'Original';
    if (_multiplier >= 0.70) return 'Low';
    return 'Very Low';
  }

  Color get _levelColor {
    if (_multiplier >= 1.30) return Colors.red.shade600;
    if (_multiplier >= 1.0)  return Colors.black;
    return Colors.blue.shade700;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final newWorkouts =
    Map<String, DayWorkout>.from(widget.plan.workouts);

    for (final entry in newWorkouts.entries.toList()) {
      final date    = DateTime.parse(entry.key);
      final wd      = date.weekday;
      final workout = entry.value;

      if (_trainingDays.contains(wd) && !workout.isRest) {
        final newRun = _rounded(_originalRun[wd]! * _multiplier);
        newWorkouts[entry.key] = DayWorkout(
          runSeconds: newRun,
          sets:       _sets,
        );
      }
    }

    final updated = TrainingPlan(
      id:        widget.plan.id,
      profile:   widget.plan.profile,
      startDate: widget.plan.startDate,
      tim:       widget.plan.tim,
      workouts:  newWorkouts,
    );

    await PlanStorage.save(updated);
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    // Compute display values for all 3 days at current multiplier
    final monRun = _rounded(_originalRun[1]! * _multiplier);
    final wedRun = _rounded(_originalRun[3]! * _multiplier);
    final friRun = _rounded(_originalRun[5]! * _multiplier);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text('Adjust Intensity',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: Colors.black38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 4),
            const Text(
              'Adjusts run duration for all training days.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),

            const SizedBox(height: 20),

            // ── Intensity level pill ─────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border:
                  Border.all(color: _levelColor.withOpacity(0.3)),
                ),
                child: Text(
                  _levelLabel,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _levelColor),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Lower / Higher buttons ────────
            Row(
              children: [
                Expanded(
                  child: _intensityBtn(
                    label: 'Lower',
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.blue.shade700,
                    onTap: () => setState(
                            () => _multiplier = (_multiplier - _step)
                            .clamp(0.40, 2.0)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _intensityBtn(
                    label: 'Higher',
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.red.shade600,
                    onTap: () => setState(
                            () => _multiplier = (_multiplier + _step)
                            .clamp(0.40, 2.0)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Preview card ──────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PREVIEW',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black38,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  _previewRow('Monday',    _fmt(monRun)),
                  const SizedBox(height: 6),
                  _previewRow('Wednesday', _fmt(wedRun)),
                  const SizedBox(height: 6),
                  _previewRow('Friday',    _fmt(friRun)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Sets stepper ──────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sets (all days)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                Row(
                  children: [
                    _stepBtn(
                      icon: Icons.remove,
                      enabled: _sets > _minSets,
                      onTap: () =>
                          setState(() => _sets = _sets - 1),
                    ),
                    SizedBox(
                      width: 46,
                      child: Center(
                        child: Text('$_sets',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                      ),
                    ),
                    _stepBtn(
                      icon: Icons.add,
                      enabled: _sets < _maxSets,
                      onTap: () =>
                          setState(() => _sets = _sets + 1),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side:
                      const BorderSide(color: Colors.black26),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                        : const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _intensityBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String day, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(day,
          style: const TextStyle(
              fontSize: 13, color: Colors.black54)),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
    ],
  );

  Widget _stepBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? Colors.black : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? Colors.white : Colors.grey.shade400),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _EditSpecificDaysDialog
//  Shows all 28 plan days in a scrollable list.
//  User taps a day to toggle it unavailable.
//  On save, UnavailableScheduler reschedules and
//  the plan is overwritten in storage.
// ─────────────────────────────────────────────

class _EditSpecificDaysDialog extends StatefulWidget {
  final TrainingPlan plan;
  const _EditSpecificDaysDialog({required this.plan});

  @override
  State<_EditSpecificDaysDialog> createState() =>
      _EditSpecificDaysDialogState();
}

class _EditSpecificDaysDialogState
    extends State<_EditSpecificDaysDialog> {

  late Set<String> _unavailable; // 'yyyy-MM-dd' keys
  bool _saving = false;

  static const _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with days already marked unavailable
    _unavailable = widget.plan.workouts.entries
        .where((e) => e.value.isUnavailable)
        .map((e) => e.key)
        .toSet();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${_dayNames[d.weekday - 1]}, ${_months[d.month]} ${d.day}';

  Future<void> _save() async {
    setState(() => _saving = true);

    // Run rescheduler with original plan's workouts + new unavailable set
    // First restore any previously rescheduled days back to original
    // by re-generating from scratch using the stored original workouts
    final rescheduled = UnavailableScheduler.reschedule(
      _baseWorkouts(),
      _unavailable,
    );

    final updated = TrainingPlan(
      id:        widget.plan.id,
      profile:   widget.plan.profile,
      startDate: widget.plan.startDate,
      tim:       widget.plan.tim,
      workouts:  rescheduled,
    );

    await PlanStorage.save(updated);
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  /// Live preview of the rescheduled plan given current _unavailable selection.
  Map<String, DayWorkout> _preview() =>
      UnavailableScheduler.reschedule(_baseWorkouts(), _unavailable);

  /// Returns the "clean" base for rescheduling.
  ///
  /// Always regenerates the original 28-day schedule from scratch using
  /// [TrainingPlanGenerator.generate], so every call starts from the same
  /// pristine workouts with correct runSeconds/sets/etc. — regardless of
  /// how many times the plan has been rescheduled before.
  ///
  /// Only [isCompleted] flags are carried over from the live plan so that
  /// finished training days are not lost.
  Map<String, DayWorkout> _baseWorkouts() {
    // 1. Regenerate the original clean plan (correct stats, no moves/flags).
    final original = TrainingPlanGenerator.generate(
      widget.plan.profile,
      widget.plan.startDate,
    ).workouts;

    // 2. Build a lookup of isCompleted flags from the current live plan,
    //    keyed by date string so we can reapply them below.
    final completedKeys = <String>{};
    for (final e in widget.plan.workouts.entries) {
      if (e.value.isCompleted) completedKeys.add(e.key);
    }

    // 3. Overlay isCompleted onto the regenerated workouts.
    final base = <String, DayWorkout>{};
    for (final e in original.entries) {
      final w = e.value;
      base[e.key] = completedKeys.contains(e.key)
          ? w.copyWith(isCompleted: true)
          : w;
    }

    return base;
  }

  @override
  Widget build(BuildContext context) {
    final previewWorkouts = _preview();

    // Build sorted entries from preview (includes any extended days)
    final sortedEntries = previewWorkouts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Group into weeks
    final weeks = <List<MapEntry<String, DayWorkout>>>[];
    List<MapEntry<String, DayWorkout>>? currentWeek;
    DateTime? weekMonday;

    for (final entry in sortedEntries) {
      final date   = DateTime.parse(entry.key);
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final mk     = _dateKey(monday);

      if (weekMonday == null || _dateKey(weekMonday) != mk) {
        currentWeek = [];
        weekMonday  = monday;
        weeks.add(currentWeek);
      }
      currentWeek!.add(entry);
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Specific Days',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      SizedBox(height: 3),
                      Text(
                        'Tap a training day to mark it unavailable. Its workout moves to the next free day.',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.black38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Scrollable full-plan list grouped by week
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int wi = 0; wi < weeks.length; wi++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text('Week ${wi + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black38,
                              letterSpacing: 0.8)),
                    ),
                    ...weeks[wi].map((entry) {
                      final date    = DateTime.parse(entry.key);
                      final workout = entry.value; // from preview

                      // A day is toggleable if the LIVE preview shows a
                      // real training workout on it (original or moved).
                      final hasTraining = !workout.isRest &&
                          !workout.isUnavailable;

                      // isMarked = user explicitly flagged this key
                      final isMarked = _unavailable.contains(entry.key);

                      // Visual distinction: was this day in the original saved
                      // plan as a training day, or was it moved here?
                      final originalWorkout = widget.plan.workouts[entry.key];
                      final wasOriginallyTraining = originalWorkout != null &&
                          !originalWorkout.isRest &&
                          !originalWorkout.isUnavailable;
                      final isMoved     = hasTraining && !wasOriginallyTraining;
                      final isTraining  = hasTraining && wasOriginallyTraining;
                      final isCompleted = workout.isCompleted;

                      // canToggle = it currently shows training (so marking
                      // makes sense) OR it's already marked (so un-marking
                      // must always be allowed).
                      // Completed days can never be marked unavailable.
                      final canToggle = (hasTraining || isMarked) && !isCompleted;

                      return _DayTile(
                        label:         _formatDate(date),
                        isTraining:    isTraining,
                        isMoved:       isMoved,
                        isUnavailable: isMarked,
                        isCompleted:   isCompleted,
                        canToggle:     canToggle,
                        workout:       workout,
                        onTap: canToggle ? () {
                          setState(() {
                            if (isMarked) {
                              _unavailable.remove(entry.key);
                            } else {
                              _unavailable.add(entry.key);
                            }
                          });
                        } : null,
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Footer buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(Colors.green, 'Training'),
                    const SizedBox(width: 5),
                    _legendDot(Colors.orange, 'Moved'),
                    const SizedBox(width: 5),
                    _legendDot(Colors.grey.shade400, 'Rest'),
                    const SizedBox(width: 5),
                    _legendDot(Colors.red.shade300, 'Unavailable'),
                    const SizedBox(width: 5),
                    _legendDot(Colors.blue.shade400, 'Completed'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.black26),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.black45)),
    ],
  );
}

// ─────────────────────────────────────────────
//  _DayTile
// ─────────────────────────────────────────────

class _DayTile extends StatelessWidget {
  final String      label;
  final bool        isTraining;
  final bool        isMoved;
  final bool        isUnavailable;
  final bool        isCompleted;
  final bool        canToggle;
  final DayWorkout  workout;
  final VoidCallback? onTap;

  const _DayTile({
    required this.label,
    required this.isTraining,
    required this.isMoved,
    required this.isUnavailable,
    required this.isCompleted,
    required this.canToggle,
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color  bgColor;
    Color  borderColor;
    Color  labelColor;
    String statusText;
    Color  statusColor;

    if (isUnavailable) {
      bgColor     = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      labelColor  = Colors.red.shade400;
      statusText  = 'Unavailable';
      statusColor = Colors.red.shade400;
    } else if (isCompleted) {
      bgColor     = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      labelColor  = Colors.blue.shade700;
      statusText  = 'Completed';
      statusColor = Colors.blue.shade600;
    } else if (isMoved) {
      bgColor     = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      labelColor  = Colors.black87;
      statusText  = 'Moved here';
      statusColor = Colors.orange.shade700;
    } else if (isTraining) {
      bgColor     = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      labelColor  = Colors.black87;
      statusText  = 'Training';
      statusColor = Colors.green.shade700;
    } else {
      bgColor     = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
      labelColor  = Colors.black45;
      statusText  = workout.isRecreational ? 'Recreational' : 'Rest';
      statusColor = Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Toggle circle — only for training days
            if (canToggle)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnavailable ? Colors.red.shade400 : Colors.transparent,
                  border: Border.all(
                    color: isUnavailable ? Colors.red.shade400 : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                child: isUnavailable
                    ? const Icon(Icons.close, size: 12, color: Colors.white)
                    : null,
              )
            else
              const SizedBox(width: 18),

            const SizedBox(width: 12),

            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor)),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusText,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}