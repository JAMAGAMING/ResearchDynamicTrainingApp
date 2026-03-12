import 'package:flutter/material.dart';
import 'calendar.dart';
import 'login.dart';
import 'reset_password.dart';
import 'training_plan_model.dart';
import 'plan_storage.dart';
import 'create_training_plan_screen.dart';
import 'select_training_plan_screen.dart';
import 'workout_session_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TrainingPlan? _activePlan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await PlanStorage.loadActive();
    if (mounted) setState(() => _activePlan = plan);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text('Username',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.person),
                color: Colors.white,
                onPressed: () => _showProfileDialog(context),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isLandscape
            ? _LandscapeLayout(
          activePlan: _activePlan,
          onPlanUpdated: (p) => setState(() => _activePlan = p),
          onSelectPlan: _openSelectPlan,
        )
            : _PortraitLayout(
          activePlan: _activePlan,
          onPlanUpdated: (p) => setState(() => _activePlan = p),
          onSelectPlan: _openSelectPlan,
        ),
      ),
    );
  }

  Future<void> _openSelectPlan() async {
    final selected = await Navigator.push<TrainingPlan?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SelectTrainingPlanScreen(activePlanId: _activePlan?.id),
      ),
    );
    // selected == null means the active plan was deleted and no plans remain
    if (mounted) setState(() => _activePlan = selected);
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('Full Name',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Username',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black),
                  onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                          (r) => false),
                  child: const Text('Log Out',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen())),
                  child: const Text('Reset Password',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Layouts
// ─────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  final TrainingPlan? activePlan;
  final void Function(TrainingPlan) onPlanUpdated;
  final VoidCallback onSelectPlan;

  const _PortraitLayout({
    required this.activePlan,
    required this.onPlanUpdated,
    required this.onSelectPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 140, child: _TotalKmWidget()),
        const SizedBox(height: 12),
        SizedBox(
            height: 140,
            child: _TrainingOfTheDayWidget(activePlan: activePlan)),
        const SizedBox(height: 12),
        SizedBox(
            height: 140,
            child:
            _CreateTrainingPlanWidget(onPlanUpdated: onPlanUpdated)),
        const SizedBox(height: 12),
        SizedBox(
            height: 140,
            child: _TrainingCalendarWidget(activePlan: activePlan)),
        const SizedBox(height: 12),
        SizedBox(
            height: 90,
            child: _SelectTrainingPlanWidget(onTap: onSelectPlan)),
      ],
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  final TrainingPlan? activePlan;
  final void Function(TrainingPlan) onPlanUpdated;
  final VoidCallback onSelectPlan;

  const _LandscapeLayout({
    required this.activePlan,
    required this.onPlanUpdated,
    required this.onSelectPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 140, child: _TotalKmWidget()),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 140,
                      child: _CreateTrainingPlanWidget(
                          onPlanUpdated: onPlanUpdated)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                      height: 140,
                      child: _TrainingOfTheDayWidget(
                          activePlan: activePlan)),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 140,
                      child: _TrainingCalendarWidget(
                          activePlan: activePlan)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
            height: 90,
            child: _SelectTrainingPlanWidget(onTap: onSelectPlan)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Shared Card
// ─────────────────────────────────────────────

class _HomeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? color;

  const _HomeCard({required this.child, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Create / Modify popup
// ─────────────────────────────────────────────

void _showTrainingPlanOptions(
    BuildContext context, {
      required void Function(TrainingPlan) onPlanUpdated,
    }) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Training Plan',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 4),
              const Text('What would you like to do?',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
              const SizedBox(height: 20),
              _planOptionTile(
                icon: Icons.add_circle_outline,
                title: 'Create Training Plan',
                subtitle: 'Build a new plan from scratch',
                onTap: () async {
                  Navigator.pop(context);
                  final plan = await Navigator.push<TrainingPlan>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const CreateTrainingPlanScreen()),
                  );
                  if (plan != null) onPlanUpdated(plan);
                },
              ),
              const SizedBox(height: 12),
              _planOptionTile(
                icon: Icons.edit_outlined,
                title: 'Modify Training Plan',
                subtitle: 'Edit your existing plan',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to Modify Training Plan page
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style:
                      TextStyle(color: Colors.black45, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _planOptionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: Colors.white54, size: 20),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Widgets
// ─────────────────────────────────────────────

class _TotalKmWidget extends StatelessWidget {
  const _TotalKmWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Kilometers Ran',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: const [
                Icon(Icons.directions_run, size: 28, color: Colors.black),
                SizedBox(width: 8),
                Text('20 km',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingOfTheDayWidget extends StatefulWidget {
  final TrainingPlan? activePlan;
  const _TrainingOfTheDayWidget({required this.activePlan});

  @override
  State<_TrainingOfTheDayWidget> createState() => _TrainingOfTheDayWidgetState();
}

class _TrainingOfTheDayWidgetState extends State<_TrainingOfTheDayWidget> {

  // Always load fresh from storage so edits (intensity/reschedule) are reflected.
  Future<void> _onTap() async {
    final plan = await PlanStorage.loadActive();
    if (!mounted) return;

    final today   = DateTime.now();
    final date    = DateTime(today.year, today.month, today.day);
    final workout = plan?.getWorkoutForDate(date);

    // Real training day → check if already completed first
    if (workout != null && !workout.isRest && !workout.isUnavailable) {
      if (workout.isCompleted) {
        _showInfoDialog(today, workout);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(workout: workout, date: date),
        ),
      );
      return;
    }

    // Not a training day → simple info dialog
    _showInfoDialog(today, workout);
  }

  void _showInfoDialog(DateTime today, DayWorkout? workout) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 22, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'Today — ${days[today.weekday - 1]}, ${today.day}/${today.month}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                workout == null
                    ? 'No active training plan. Create one from the home screen!'
                    : workout.isCompleted
                    ? '✅ You already completed today\'s workout. Great work!'
                    : workout.isUnavailable
                    ? 'You marked today as unavailable. Your workout was moved to another day.'
                    : workout.isRecreational
                    ? '🌿 Rest / Recreational Day — light activity or full rest.'
                    : '😴 Rest Day — recover and hydrate.',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: _onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.wb_sunny_outlined, size: 28, color: Colors.black),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Training of the Day',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          SizedBox(height: 4),
          Text("View today's workout",
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _CreateTrainingPlanWidget extends StatelessWidget {
  final void Function(TrainingPlan) onPlanUpdated;
  const _CreateTrainingPlanWidget({required this.onPlanUpdated});

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () =>
          _showTrainingPlanOptions(context, onPlanUpdated: onPlanUpdated),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.edit_note, size: 28, color: Colors.black),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Create/Modify Training Plan',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
          SizedBox(height: 4),
          Text('Build a new plan',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _TrainingCalendarWidget extends StatelessWidget {
  final TrainingPlan? activePlan;
  const _TrainingCalendarWidget({required this.activePlan});

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  TrainingCalendarPage(activePlan: activePlan)),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.calendar_month, size: 28, color: Colors.black),
                SizedBox(height: 8),
                Text('Training Calendar',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                SizedBox(height: 4),
                Text('View your schedule',
                    style:
                    TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 28, color: Colors.black45),
        ],
      ),
    );
  }
}

class _SelectTrainingPlanWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _SelectTrainingPlanWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      color: Colors.white,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 28, color: Colors.black),
              SizedBox(width: 12),
              Text('Select Training Plan',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
          Icon(Icons.chevron_right, size: 28, color: Colors.black45),
        ],
      ),
    );
  }
}