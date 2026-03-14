import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_plan_model.dart';

// ─────────────────────────────────────────────
//  PlanStorage — stores multiple training plans
//  and tracks which one is currently active.
//
//  Keys used in SharedPreferences:
//    'plans'          → JSON list of all saved plans
//    'active_plan_id' → id of the currently selected plan
//
//  Note: all writes go through a single SharedPreferences
//  instance obtained once per call to avoid the race
//  condition where save() calls loadAll() separately,
//  potentially reading stale data between two rapid saves.
// ─────────────────────────────────────────────

class PlanStorage {
  static const _plansKey    = 'plans';
  static const _activeIdKey = 'active_plan_id';

  // ── Save a plan (replaces if same id exists, appends otherwise) ──

  static Future<void> save(TrainingPlan plan) async {
    // Obtain prefs once and pass it through so loadAll doesn't
    // open a second instance that might read before this write lands.
    final prefs = await SharedPreferences.getInstance();
    final plans = _decodePlans(prefs.getString(_plansKey));

    final idx = plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      plans[idx] = plan;
    } else {
      plans.add(plan);
    }

    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
    await prefs.setString(_activeIdKey, plan.id);
  }

  // ── Load all saved plans ──

  static Future<List<TrainingPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodePlans(prefs.getString(_plansKey));
  }

  // ── Load the currently active plan ──

  static Future<TrainingPlan?> loadActive() async {
    final prefs    = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeIdKey);
    if (activeId == null) return null;
    final plans = _decodePlans(prefs.getString(_plansKey));
    try {
      return plans.firstWhere((p) => p.id == activeId);
    } catch (_) {
      return plans.isNotEmpty ? plans.last : null;
    }
  }

  // ── Set which plan is active ──

  static Future<void> setActive(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, planId);
  }

  // ── Delete a plan by id ──

  static Future<void> delete(String planId) async {
    final prefs  = await SharedPreferences.getInstance();
    final plans  = _decodePlans(prefs.getString(_plansKey));
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
  }

  // ── Clear everything ──

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plansKey);
    await prefs.remove(_activeIdKey);
    await prefs.remove(_totalMetersKey);
  }

  // ── Total meters run (lifetime, across all sessions) ──────────────────────
  //
  //  Stored as a plain double under 'total_meters_run'.
  //  addMeters() reads, increments, and writes within a single prefs instance
  //  to avoid lost-update races between rapid calls.

  static const _totalMetersKey = 'total_meters_run';

  /// Returns the total meters run so far (0.0 if never set).
  static Future<double> loadTotalMeters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_totalMetersKey) ?? 0.0;
  }

  /// Adds [meters] to the running total and persists it.
  /// No-ops when meters <= 0.
  static Future<void> addMeters(double meters) async {
    if (meters <= 0) return;
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_totalMetersKey) ?? 0.0;
    await prefs.setDouble(_totalMetersKey, current + meters);
  }

  /// Overwrites the total with an explicit value (useful for corrections).
  static Future<void> setTotalMeters(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_totalMetersKey, meters.clamp(0.0, double.infinity));
  }

  // ── Internal helper ──────────────────────────────────────────────────────
  //  Decodes the raw JSON string into a list of TrainingPlans.
  //  Returns an empty list on null input or any parse error.

  static List<TrainingPlan> _decodePlans(String? raw) {
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