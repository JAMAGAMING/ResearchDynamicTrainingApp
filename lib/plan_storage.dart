import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_plan_model.dart';
import 'sync_service.dart';
import 'auth_storage.dart';

// ─────────────────────────────────────────────
//  PlanStorage  (simplified)
//
//  Keys in SharedPreferences:
//    'plans'          → JSON list of all saved plans
//    'active_plan_id' → id of the currently selected plan
//
//  Ownership rules:
//    ownerId == "offline" → visible to everyone (guest + all accounts)
//    ownerId == <userId>  → visible only to that logged-in user
//
//  Guest session  → loadAll() returns only offline plans
//  User session   → loadAll() returns that user's plans + offline plans
// ─────────────────────────────────────────────

class PlanStorage {
  static const _plansKey    = 'plans';
  static const _activeIdKey = 'active_plan_id';

  // ── Save a plan ───────────────────────────────────────────────────────────
  // Replaces existing plan with the same id, or appends if new.
  // Sets it as the active plan and pushes to server in the background.
  static Future<void> save(TrainingPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = _decode(prefs.getString(_plansKey));

    final idx = plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      plans[idx] = plan;
    } else {
      plans.add(plan);
    }

    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
    await prefs.setString(_activeIdKey, plan.id);

    // Push to server in the background — does not block local save.
    SyncService.pushPlan(plan);
  }

  // ── Save without changing the active plan ────────────────────────────────
  // Used by SyncService when pulling plans from the server.
  // Does NOT push back to the server.
  static Future<void> saveWithoutActivating(TrainingPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = _decode(prefs.getString(_plansKey));

    final idx = plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      plans[idx] = plan;
    } else {
      plans.add(plan);
    }

    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
  }

  // ── Load plans visible to the current session ─────────────────────────────
  // Guest  → offline plans only
  // User   → their plans + offline plans
  static Future<List<TrainingPlan>> loadAll() async {
    final prefs  = await SharedPreferences.getInstance();
    final all    = _decode(prefs.getString(_plansKey));
    final userId = await _currentUserId();
    return _filterByOwner(all, userId);
  }

  // ── Load ALL plans regardless of owner (used by SyncService) ─────────────
  static Future<List<TrainingPlan>> loadAllUnfiltered() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_plansKey));
  }

  // ── Load the active plan ──────────────────────────────────────────────────
  static Future<TrainingPlan?> loadActive() async {
    final prefs    = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeIdKey);
    final plans    = await loadAll(); // filtered for current session
    if (activeId != null) {
      try {
        return plans.firstWhere((p) => p.id == activeId);
      } catch (_) {}
    }
    return plans.isNotEmpty ? plans.first : null;
  }

  // ── Set the active plan ───────────────────────────────────────────────────
  static Future<void> setActive(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, planId);
  }

  // ── Delete a plan ─────────────────────────────────────────────────────────
  static Future<void> delete(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = _decode(prefs.getString(_plansKey));
    plans.removeWhere((p) => p.id == planId);
    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));

    final activeId = prefs.getString(_activeIdKey);
    if (activeId == planId) {
      if (plans.isNotEmpty) {
        await prefs.setString(_activeIdKey, plans.last.id);
      } else {
        await prefs.remove(_activeIdKey);
      }
    }

    // Mirror deletion to server — fire-and-forget.
    SyncService.deletePlan(planId);
  }

  // ── Clear everything ──────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plansKey);
    await prefs.remove(_activeIdKey);
    await prefs.remove(_totalMetersKey);
  }

  // ── Total meters run ──────────────────────────────────────────────────────
  static const _totalMetersKey = 'total_meters_run';

  static Future<double> loadTotalMeters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_totalMetersKey) ?? 0.0;
  }

  static Future<void> addMeters(double meters) async {
    if (meters <= 0) return;
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_totalMetersKey) ?? 0.0;
    await prefs.setDouble(_totalMetersKey, current + meters);
  }

  static Future<void> setTotalMeters(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_totalMetersKey, meters.clamp(0.0, double.infinity));
  }

  // ── Per-plan step tracking ────────────────────────────────────────────────
  static Future<void> addStepsToActivePlan(int steps) async {
    if (steps <= 0) return;
    final plan = await loadActive();
    if (plan == null) return;

    final updated = TrainingPlan(
      id:                    plan.id,
      profile:               plan.profile,
      startDate:             plan.startDate,
      tim:                   plan.tim,
      workouts:              plan.workouts,
      intensityDeltaSeconds: plan.intensityDeltaSeconds,
      setsDelta:             plan.setsDelta,
      totalSteps:            plan.totalSteps + steps,
      ownerId:               plan.ownerId, // always preserve original owner
      lastModifiedAt:        DateTime.now().toUtc(),
    );

    await save(updated);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Future<String?> _currentUserId() async {
    final user = await AuthStorage.getUser();
    final id   = user?['id'];
    if (id == null) return null;
    return id.toString();
  }

  static List<TrainingPlan> _filterByOwner(
      List<TrainingPlan> plans, String? userId) {
    if (userId == null) {
      return plans; // guest — sees all local plans
    }
    // Logged-in — their own plans + offline plans
    return plans
        .where((p) => p.ownerId == userId || p.ownerId == TrainingPlan.ownerOffline)
        .toList();
  }

  static List<TrainingPlan> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => TrainingPlan.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}