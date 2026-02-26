import 'package:flutter/material.dart';
import 'calendar.dart';

// ─────────────────────────────────────────────
//  HOW TO USE IN YOUR main.dart:
//
//  1. Import this file:
//       import 'homepage.dart';
//
//  2. Set it as your home:
//       home: const HomePage(),
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  Portrait: stacked vertically
// ─────────────────────────────────────────────
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Landscape: 2x2 grid
// ─────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
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
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable card base
// ─────────────────────────────────────────────
class _HomeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HomeCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widget 1 — Total Kilometers Ran
// ─────────────────────────────────────────────
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
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
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widget 2 — Training of the Day
// ─────────────────────────────────────────────
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'View today\'s workout',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widget 3 — Create Training Plan
// ─────────────────────────────────────────────
class _CreateTrainingPlanWidget extends StatelessWidget {
  const _CreateTrainingPlanWidget();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: () {
        // TODO: navigate to create training plan page
      },
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Build a new plan',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widget 4 — Training Calendar
// ─────────────────────────────────────────────
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View your schedule',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 28, color: Colors.black45),
        ],
      ),
    );
  }
}