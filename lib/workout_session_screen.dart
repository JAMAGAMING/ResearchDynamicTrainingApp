import 'dart:async';
import 'dart:convert';
import 'dart:math' show asin, cos, pi, sin, sqrt;
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
//  • When the timer reaches 0:00.00 the alarm rings and the step is
//    auto-checked (except Stretching, which rings but waits for
//    the user to tap to confirm).
//  • Unchecking a step cancels and resets its timer.
//  • When all steps are checked → show completion dialog.
//
//  Timer precision:
//  • Internally tracked in centiseconds (1/100 s) for smooth display.
//  • Ticker fires every 10 ms for a ~2-decimal countdown (M:SS.cs).
//  • SessionProgress persists centiseconds so resume is accurate.
//
//  GPS distance tracking:
//  • Tracking is active ONLY during Run step countdowns (not paused,
//    not walk/warmup/cooldown/stretch).
//  • Uses geolocator's position stream; consecutive fixes are
//    accumulated with the Haversine formula for accuracy.
//  • Requires location permission (requested on screen open).
//    If denied, session proceeds normally — km counter is unaffected.
//  • Accumulated meters are flushed to PlanStorage on dispose so
//    partial sessions are credited even if the user navigates away.
//
//  Dependencies (add to pubspec.yaml):
//    flutter_ringtone_player: ^4.0.0
//    geolocator: ^13.0.0
//
//  Android AndroidManifest.xml:
//    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//
//  iOS Info.plist:
//    <key>NSLocationWhenInUseUsageDescription</key>
//    <string>Used to track distance during your run.</string>
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  SessionProgress — persists mid-session state
//
//  Stored in SharedPreferences under the key:
//    'session_progress_<yyyy-MM-dd>'
//
//  Fields saved:
//    checkedSteps          → List<bool> — which steps are ticked
//    activeIndex           → int?       — step whose timer was running
//    remainingCentiseconds → int        — centiseconds left on that timer
// ─────────────────────────────────────────────

class SessionProgress {
  static String _key(DateTime date) =>
      'session_progress_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<void> save({
    required DateTime   date,
    required List<bool> checkedSteps,
    required int?       activeIndex,
    required int        remainingCentiseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data  = jsonEncode({
      'checkedSteps':           checkedSteps,
      'activeIndex':            activeIndex,
      'remainingCentiseconds':  remainingCentiseconds,
      // Legacy field kept for backwards compat
      'remainingSeconds':       remainingCentiseconds ~/ 100,
    });
    await prefs.setString(_key(date), data);
  }

  /// Returns null if no saved progress exists for this date.
  static Future<Map<String, dynamic>?> load(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key(date));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(date));
  }
}

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
  // All durations are stored in centiseconds (1/100 s).
  int?   _activeIndex;
  int    _remaining = 0; // centiseconds
  bool   _isPaused  = false;
  Timer? _ticker;

  // ── GPS tracking ──────────────────────────────
  // Active only while a Run step's countdown is running (not paused).
  // Flushed to PlanStorage.addMeters() on dispose.
  StreamSubscription<Position>? _positionSub;
  Position?                     _lastPosition;
  double                        _sessionMeters = 0.0;
  bool                          _gpsAvailable  = false;

  @override
  void initState() {
    super.initState();
    _steps   = _buildSteps(widget.workout);
    _checked = List.filled(_steps.length, false);
    _restoreProgress();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _stopGps();
    // Flush GPS meters earned this session (even partial).
    PlanStorage.addMeters(_sessionMeters);
    if (!_checked.every((c) => c)) {
      SessionProgress.save(
        date:                  widget.date,
        checkedSteps:          List.of(_checked),
        activeIndex:           _activeIndex,
        remainingCentiseconds: _remaining,
      );
    }
    super.dispose();
  }

  // ── Restore mid-session progress ──────────────
  Future<void> _restoreProgress() async {
    final saved = await SessionProgress.load(widget.date);
    if (saved == null) return;

    final steps  = (saved['checkedSteps'] as List<dynamic>).cast<bool>();
    final active = saved['activeIndex'] as int?;

    // Support both new centiseconds field and legacy seconds field.
    final int remaining;
    if (saved.containsKey('remainingCentiseconds')) {
      remaining = saved['remainingCentiseconds'] as int;
    } else {
      remaining = ((saved['remainingSeconds'] as int?) ?? 0) * 100;
    }

    if (steps.length != _checked.length) return;
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < steps.length; i++) _checked[i] = steps[i];
      // Restore paused — safer than auto-resuming a countdown they can't see.
      if (active != null && active < _steps.length && remaining > 0) {
        _activeIndex = active;
        _remaining   = remaining;
        _isPaused    = true;
      }
    });
  }

  // ── GPS helpers ───────────────────────────────

  /// Requests location permission once on screen open.
  /// Sets [_gpsAvailable] so we know whether to start tracking.
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      if (permission == LocationPermission.denied)        return;

      if (mounted) setState(() => _gpsAvailable = true);
    } catch (_) {
      // Permission plugin not available in test/web — degrade gracefully.
    }
  }

  /// Starts the GPS position stream for a Run step.
  /// No-ops if GPS is unavailable or already running.
  void _startGps() {
    if (!_gpsAvailable || _positionSub != null) return;
    _lastPosition = null; // reset reference point for this run interval

    const locationSettings = LocationSettings(
      accuracy:          LocationAccuracy.high,
      distanceFilter:    3, // minimum metres between updates
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) {
      if (_lastPosition != null) {
        _sessionMeters += _haversineMeters(_lastPosition!, pos);
      }
      _lastPosition = pos;
    }, onError: (_) {
      // Stream error (e.g. permission revoked mid-run) — stop quietly.
      _stopGps();
    });
  }

  /// Stops and cleans up the GPS stream.
  void _stopGps() {
    _positionSub?.cancel();
    _positionSub  = null;
    _lastPosition = null;
  }

  /// Haversine formula — straight-line surface distance between two positions.
  static double _haversineMeters(Position a, Position b) {
    const r = 6371000.0; // Earth radius in metres
    final lat1 = a.latitude  * pi / 180;
    final lat2 = b.latitude  * pi / 180;
    final dLat = (b.latitude  - a.latitude)  * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * asin(sqrt(h));
  }

  // ── Build flat sequential step list ──────────
  static List<_Step> _buildSteps(DayWorkout w) {
    final list = <_Step>[];

    list.add(_Step(
      type:              _T.warmup,
      label:             'Warm-up',
      detail:            '5:00 easy jog',
      timerCentiseconds: w.warmupSeconds * 100,
    ));

    for (int i = 1; i <= w.sets; i++) {
      list.add(_Step(
        type:              _T.run,
        label:             'Run',
        detail:            w.runDisplay,
        setNum:            i,
        totalSets:         w.sets,
        timerCentiseconds: w.runSeconds * 100,
      ));
      list.add(_Step(
        type:              _T.walk,
        label:             'Walk',
        detail:            '2:00',
        setNum:            i,
        totalSets:         w.sets,
        timerCentiseconds: w.walkSeconds * 100,
      ));
    }

    list.add(_Step(
      type:              _T.cooldown,
      label:             'Cool-down',
      detail:            '5:00 easy jog',
      timerCentiseconds: w.cooldownSeconds * 100,
    ));
    // Stretching: 5-min suggested timer, rings as nudge but does NOT auto-check.
    list.add(_Step(
      type:              _T.stretch,
      label:             'Stretching',
      detail:            '5–10 min',
      timerCentiseconds: 300 * 100,
    ));

    return list;
  }

  // ── State helpers ─────────────────────────────
  bool   get _allDone   => _checked.every((c) => c);
  int    get _doneCount => _checked.where((c) => c).length;
  double get _progress  => _steps.isEmpty ? 0.0 : _doneCount / _steps.length;

  bool _canCheck(int i) => i == 0 || _checked[i - 1];

  // ── Persist mid-session progress ─────────────
  void _saveProgress() {
    SessionProgress.save(
      date:                  widget.date,
      checkedSteps:          List.of(_checked),
      activeIndex:           _activeIndex,
      remainingCentiseconds: _remaining,
    );
  }

  // ── Timer control ─────────────────────────────

  /// Fires every 10 ms; decrements _remaining by 1 centisecond each tick.
  void _startTicker(int i) {
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
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
    // Start GPS only for Run steps; stop it for any other step type.
    if (_steps[i].type == _T.run) {
      _startGps();
    } else {
      _stopGps();
    }
    setState(() {
      _activeIndex = i;
      _isPaused    = false;
      _remaining   = _steps[i].timerCentiseconds;
    });
    _startTicker(i);
  }

  void _pauseTimer() {
    _ticker?.cancel();
    _ticker = null;
    _stopGps(); // pause GPS — don't count standing-still distance
    setState(() => _isPaused = true);
  }

  void _resumeTimer() {
    // Resume GPS only if this is a Run step.
    if (_activeIndex != null && _steps[_activeIndex!].type == _T.run) {
      _startGps();
    }
    setState(() => _isPaused = false);
    _startTicker(_activeIndex!);
  }

  void _cancelTimer() {
    _ticker?.cancel();
    _ticker = null;
    _stopGps();
    setState(() {
      _activeIndex = null;
      _remaining   = 0;
      _isPaused    = false;
    });
  }

  /// Stops the ticker and restores the step's full duration WITHOUT
  /// starting a new countdown — the user must tap to begin again.
  void _resetTimer(int i) {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _activeIndex = i;
      _remaining   = _steps[i].timerCentiseconds;
      _isPaused    = true; // keep tile visible so user can tap to start
    });
  }

  void _onTimerFinished(int i) {
    FlutterRingtonePlayer().playAlarm(looping: false);
    _stopGps(); // step ended — GPS off until the next Run step starts

    final isStretch = _steps[i].type == _T.stretch;

    setState(() {
      _activeIndex = null;
      _remaining   = 0;
      _isPaused    = false;
      if (!isStretch) _checked[i] = true;
    });

    _saveProgress();

    if (!isStretch && _allDone) {
      SessionProgress.clear(widget.date);
      Future.delayed(const Duration(milliseconds: 350), _showCompletionDialog);
    }
  }

  // ── Body tap → start / pause / resume timer ───
  void _onBodyTap(int i) {
    if (!_canCheck(i) || _checked[i]) return;

    if (_activeIndex == i) {
      _isPaused ? _resumeTimer() : _pauseTimer();
      return;
    }

    if (_activeIndex != null) _cancelTimer();
    _startTimer(i);
  }

  // ── Checkbox tap → manual mark complete / uncheck ──
  void _onCheckTap(int i) {
    if (!_canCheck(i) && !_checked[i]) return;

    if (_checked[i]) {
      if (_activeIndex != null && _activeIndex! >= i) _cancelTimer();
      setState(() {
        for (int j = i; j < _checked.length; j++) _checked[j] = false;
      });
      _saveProgress();
      return;
    }

    if (_activeIndex == i) _cancelTimer();
    setState(() => _checked[i] = true);

    if (_allDone) {
      SessionProgress.clear(widget.date);
      Future.delayed(const Duration(milliseconds: 350), _showCompletionDialog);
    } else {
      _saveProgress();
    }
  }

  // ── Reset tap → restart timer from full duration ──
  void _onResetTap(int i) {
    if (_activeIndex != i && !(_isPaused && _activeIndex == i)) return;
    _resetTimer(i);
    _saveProgress();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                    color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
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
            dateLabel:     _dateLabel,
            progress:      _progress,
            doneCount:     _doneCount,
            totalCount:    _steps.length,
            sessionMeters: _sessionMeters,
            gpsAvailable:  _gpsAvailable,
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
                      remainingCs: isTiming ? _remaining : step.timerCentiseconds,
                      onBodyTap:   () => _onBodyTap(i),
                      onCheckTap:  () => _onCheckTap(i),
                      onResetTap:  () => _onResetTap(i),
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
  final double sessionMeters;  // GPS distance accumulated this session
  final bool   gpsAvailable;   // whether location permission was granted

  const _ProgressHeader({
    required this.dateLabel,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
    required this.sessionMeters,
    required this.gpsAvailable,
  });

  String get _distanceLabel {
    if (!gpsAvailable) return 'GPS off';
    final km = sessionMeters / 1000.0;
    if (km >= 1.0) return '${km.toStringAsFixed(2)} km';
    return '${sessionMeters.toStringAsFixed(0)} m';
  }

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
              // Right side: step count + live distance chip
              Row(
                children: [
                  Text('$doneCount / $totalCount steps',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gpsAvailable
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          gpsAvailable ? Icons.gps_fixed : Icons.gps_off,
                          size: 11,
                          color: gpsAvailable ? Colors.white54 : Colors.white24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _distanceLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: gpsAvailable ? Colors.white54 : Colors.white24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  final int          remainingCs; // centiseconds to display
  final VoidCallback onBodyTap;   // start / pause / resume
  final VoidCallback onCheckTap;  // manual check / uncheck
  final VoidCallback onResetTap;  // reset timer back to full duration

  const _StepTile({
    required this.step,
    required this.isChecked,
    required this.isLocked,
    required this.isTiming,
    required this.isPaused,
    required this.remainingCs,
    required this.onBodyTap,
    required this.onCheckTap,
    required this.onResetTap,
  });

  Color get _bg {
    if (isChecked) return Colors.green.shade400;
    if (isPaused)  return Colors.grey.shade900;
    if (isTiming)  return Colors.blue.shade700.withOpacity(0.35);
    if (isLocked)  return Colors.white.withOpacity(0.04);
    return Colors.white.withOpacity(0.10);
  }

  Color get _border {
    if (isChecked) return Colors.green.shade400;
    if (isPaused)  return Colors.grey.withOpacity(0.45);
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

  /// Formats centiseconds as  M:SS.cs  (e.g. 1:20.53)
  static String _fmt(int cs) {
    final clamped      = cs.clamp(0, cs); // ensure non-negative display
    final totalSeconds = clamped ~/ 100;
    final centis       = clamped % 100;
    final m            = totalSeconds ~/ 60;
    final s            = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timerFraction = step.timerCentiseconds > 0
        ? (remainingCs / step.timerCentiseconds).clamp(0.0, 1.0)
        : 0.0;

    // Turn red in the last 10 seconds (= 1000 centiseconds).
    final timerColor = (isTiming && remainingCs <= 1000)
        ? Colors.red.shade300
        : Colors.white70;

    Widget? checkIcon;
    if (isChecked) {
      checkIcon = const Icon(Icons.check, size: 15, color: Colors.black);
    } else if (isLocked) {
      checkIcon = const Icon(Icons.lock_outline, size: 13, color: Colors.white12);
    }

    return GestureDetector(
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
                    _fmt(remainingCs),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isTiming ? timerColor : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // ── Reset button (only while timing or paused) ──
                if ((isTiming || isPaused) && !isChecked) ...[
                  GestureDetector(
                    onTap: onResetTap,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 2),
                      ),
                      child: const Icon(
                        Icons.replay_rounded,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
  final int    timerCentiseconds; // full countdown in centiseconds (1/100 s)
  final int?   setNum;
  final int?   totalSets;

  const _Step({
    required this.type,
    required this.label,
    required this.detail,
    required this.timerCentiseconds,
    this.setNum,
    this.totalSets,
  });
}