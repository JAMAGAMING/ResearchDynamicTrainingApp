import 'package:flutter/material.dart';
import 'calendar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isLandscape ? const _LandscapeLayout() : const _PortraitLayout(),
      ),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 140, child: _TotalKmWidget()),
        SizedBox(height: 12),
        SizedBox(height: 140, child: _TrainingOfTheDayWidget()),
        SizedBox(height: 12),
        SizedBox(height: 140, child: _CreateTrainingPlanWidget()),
        SizedBox(height: 12),
        SizedBox(height: 140, child: _TrainingCalendarWidget()),
        SizedBox(height: 12),
        SizedBox(height: 90, child: _SelectTrainingPlanWidget()),
      ],
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 140, child: _TotalKmWidget()),
                  SizedBox(height: 12),
                  SizedBox(height: 140, child: _CreateTrainingPlanWidget()),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 140, child: _TrainingOfTheDayWidget()),
                  SizedBox(height: 12),
                  SizedBox(height: 140, child: _TrainingCalendarWidget()),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(height: 90, child: _SelectTrainingPlanWidget()),
      ],
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Popup — Create / Modify Training Plan
// ─────────────────────────────────────────────
void _showTrainingPlanOptions(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Training Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What would you like to do?',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
                const SizedBox(height: 20),

                // Option 1 — Create Training Plan
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Create Training Plan page
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Training Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Build a new plan from scratch',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2 — Modify Training Plan
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Modify Training Plan page
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modify Training Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Edit your existing plan',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TotalKmWidget extends StatelessWidget {
  const _TotalKmWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {
        // TODO: navigate to total km page
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Kilometers Ran',
            style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: const [
                Icon(Icons.directions_run, size: 28, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  '20 km',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingOfTheDayWidget extends StatelessWidget {
  const _TrainingOfTheDayWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {
        // TODO: navigate to training of the day page
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.wb_sunny_outlined, size: 28, color: Colors.black),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Training of the Day',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          SizedBox(height: 4),
          Text('View today\'s workout', style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _CreateTrainingPlanWidget extends StatelessWidget {
  const _CreateTrainingPlanWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () => _showTrainingPlanOptions(context), // ← triggers popup
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.edit_note, size: 28, color: Colors.black),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Create/Modify Training Plan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          SizedBox(height: 4),
          Text('Build a new plan', style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _TrainingCalendarWidget extends StatelessWidget {
  const _TrainingCalendarWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrainingCalendarPage()),
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
                Text(
                  'Training Calendar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                SizedBox(height: 4),
                Text('View your schedule', style: TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 28, color: Colors.black45),
        ],
      ),
    );
  }
}

class _SelectTrainingPlanWidget extends StatelessWidget {
  const _SelectTrainingPlanWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      color: Colors.white,
      onTap: () {
        // TODO: navigate to select training plan page
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 28, color: Colors.black),
              SizedBox(width: 12),
              Text(
                'Select Training Plan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ],
          ),
          Icon(Icons.chevron_right, size: 28, color: Colors.black45),
        ],
      ),
    );
  }
}