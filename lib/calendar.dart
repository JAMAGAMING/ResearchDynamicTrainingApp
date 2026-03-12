import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'training_plan_model.dart';
import 'plan_storage.dart';

class TrainingCalendarPage extends StatefulWidget {
  final TrainingPlan? activePlan;

  const TrainingCalendarPage({super.key, this.activePlan});

  @override
  State<TrainingCalendarPage> createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TrainingPlan? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await PlanStorage.loadActive();
    if (mounted) setState(() => _plan = plan);
  }

  bool _isCompletedDay(DateTime day) {
    final w = _plan?.getWorkoutForDate(day);
    return w != null && w.isCompleted;
  }

  bool _isWorkoutDay(DateTime day) {
    final w = _plan?.getWorkoutForDate(day);
    return w != null && !w.isRest && !w.isUnavailable;
  }

  bool _isUnavailableDay(DateTime day) {
    final w = _plan?.getWorkoutForDate(day);
    return w != null && w.isUnavailable;
  }

  bool _isRestDay(DateTime day) {
    final w = _plan?.getWorkoutForDate(day);
    return w != null && w.isRest && !w.isUnavailable;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _showDayDialog(selectedDay);
  }

  void _showDayDialog(DateTime day) {
    final workout = _plan?.getWorkoutForDate(day);

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
                '${_weekdayName(day.weekday)}, ${day.day}/${day.month}/${day.year}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const Divider(),

              if (workout == null) ...[
                const Text('🗓 No Training Plan',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 8),
                const Text(
                  'This day is not part of your active training plan. '
                      'Create a plan from the home screen.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),

              ] else if (workout.isUnavailable) ...[
                const Text('🚫 Unavailable',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(height: 10),
                const Text('• You marked this day as unavailable.',
                    style: TextStyle(color: Colors.black54)),
                const Text('• The workout was moved to the nearest free day.',
                    style: TextStyle(color: Colors.black54)),

              ] else if (workout.isRest && workout.isRecreational) ...[
                const Text('🌿 Rest / Recreational Day',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 10),
                const Text(
                    '• Optional light activity: walking, yoga, or stretching.',
                    style: TextStyle(color: Colors.black)),
                const Text('• Focus on rest, hydration, and recovery.',
                    style: TextStyle(color: Colors.black)),

              ] else if (workout.isRest) ...[
                const Text('😴 Rest Day',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 10),
                const Text('• Full rest — no running today.',
                    style: TextStyle(color: Colors.black)),
                const Text('• Stay hydrated and get good sleep.',
                    style: TextStyle(color: Colors.black)),

              ] else if (workout.isCompleted) ...[
                const Text('✅ Workout Completed',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(height: 10),
                const Text(
                  'Great job! You completed this workout.',
                  style: TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 10),
                _statRow('Warm-up', workout.warmupDisplay),
                _statRow('Run interval', workout.runDisplay),
                _statRow('Walk interval', workout.walkDisplay),
                _statRow('Sets', '${workout.sets}'),
                _statRow('Cool-down', workout.cooldownDisplay),

              ] else ...[
                const Text('🏃 Training Day',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 10),
                _statRow('Warm-up', workout.warmupDisplay),
                _statRow('Run interval', workout.runDisplay),
                _statRow('Walk interval', workout.walkDisplay),
                _statRow('Sets', '${workout.sets}'),
                _statRow('Cool-down', workout.cooldownDisplay),
              ],

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
            const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
      ],
    ),
  );

  String _weekdayName(int wd) =>
      ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][wd - 1];

  Widget _buildDayCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    Color bg;

    if (_isRestDay(day)) {
    bg = Colors.orange.shade300;
    } else if (_isUnavailableDay(day)) {
      bg = Colors.red.shade300;
    } else if (_isCompletedDay(day)) {
      bg = Colors.blue.shade400;
    } else if (_isWorkoutDay(day)) {
      bg = Colors.green.shade400;
    }  else {
      bg = isToday ? Colors.grey.shade700 : Colors.white;
    }

    final textColor = (bg == Colors.white) ? Colors.black : Colors.white;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(6),
        border: isSelected
            ? Border.all(color: Colors.white, width: 2.5)
            : isToday
            ? Border.all(color: Colors.white54, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: isSelected || isToday
              ? FontWeight.bold
              : FontWeight.normal,
          decoration:
          _isUnavailableDay(day) ? TextDecoration.lineThrough : null,
          decorationColor: Colors.white,
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
        title: const Text('Training Calendar',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TableCalendar(
              availableGestures: AvailableGestures.horizontalSwipe,
              firstDay: DateTime(2024),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day),
                todayBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isToday: true),
                selectedBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isSelected: true),
                outsideBuilder: (context, day, focusedDay) => Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('${day.day}',
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13)),
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                TextStyle(color: Colors.white, fontSize: 16),
                leftChevronIcon:
                Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon:
                Icon(Icons.chevron_right, color: Colors.white),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle:
                TextStyle(color: Colors.white70, fontSize: 12),
                weekendStyle:
                TextStyle(color: Colors.white70, fontSize: 12),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: true,
              ),
            ),

            if (_plan != null)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(Colors.green.shade400, 'Training'),
                    const SizedBox(width: 20),
                    _legendDot(Colors.orange.shade300, 'Rest'),
                    const SizedBox(width: 20),
                    _legendDot(Colors.blue.shade400, 'Completed'),
                    const SizedBox(width: 20),
                    _legendDot(Colors.red.shade300, 'Unavailable'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label,
          style:
          const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}