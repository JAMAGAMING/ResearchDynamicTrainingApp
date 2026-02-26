import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

// ─────────────────────────────────────────────
//  HOW TO USE IN YOUR main.dart:
//
//  1. Add to pubspec.yaml:
//       dependencies:
//         table_calendar: ^3.1.2
//
//  2. Import this file:
//       import 'training_calendar.dart';
//
//  3. Navigate to it:
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => const TrainingCalendarPage()),
//       );
// ─────────────────────────────────────────────

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  State<TrainingCalendarPage> createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Events map — add your events here later
  // Key: DateTime (normalised to midnight), Value: list of event strings
  final Map<DateTime, List<String>> _events = {};

  DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  List<String> _getEventsForDay(DateTime day) =>
      _events[_normalise(day)] ?? [];

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _showDayDialog(selectedDay);
  }

  void _showDayDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.day}/${day.month}/${day.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Divider(),
              const Text(
                '🏃 Training Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              const Text('• Warm-up: 10 min easy jog', style: TextStyle(color: Colors.black)),
              const Text('• Main Set: 8km at tempo pace', style: TextStyle(color: Colors.black)),
              const Text('• Intervals: 4x800m at 5K pace', style: TextStyle(color: Colors.black)),
              const Text('• Cool-down: 10 min easy jog', style: TextStyle(color: Colors.black)),
              const Text('• Stretching: 10 min', style: TextStyle(color: Colors.black)),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Training Calendar', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.black,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TableCalendar(
                availableGestures: AvailableGestures.horizontalSwipe, // lets SingleChildScrollView handle all gestures
                rowHeight: 100,
                firstDay: DateTime(2024),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                eventLoader: _getEventsForDay,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white),
                  weekendStyle: TextStyle(color: Colors.white),
                ),
                calendarStyle: CalendarStyle(
                  cellAlignment: Alignment.topLeft,
                  cellPadding: const EdgeInsets.only(top: 4, left: 6),
                  defaultDecoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.black),
                  weekendDecoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.black),
                  outsideDecoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.rectangle,
                  ),
                  outsideTextStyle: TextStyle(color: Colors.grey.shade600),
                  todayDecoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    shape: BoxShape.rectangle,
                  ),
                  todayTextStyle: const TextStyle(color: Colors.black),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.rectangle,
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.black),
                  markerDecoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}