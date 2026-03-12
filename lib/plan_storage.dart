import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_plan_model.dart';

// ─────────────────────────────────────────────
//  PlanStorage — stores multiple training plans
//  and tracks which one is currently active.
//
//  Keys used in SharedPreferences:
//    'plans'       → JSON list of all saved plans
//    'active_plan_id' → id of the currently selected plan
// ─────────────────────────────────────────────

class PlanStorage {
  static const _plansKey    = 'plans';
  static const _activeIdKey = 'active_plan_id';

  // ── Save a new plan (appends to list, sets as active) ──

  static Future<void> save(TrainingPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await loadAll();

    // Replace if same id exists, otherwise append
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
    final raw   = prefs.getString(_plansKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => TrainingPlan.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Load the currently active plan ──

  static Future<TrainingPlan?> loadActive() async {
    final prefs    = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeIdKey);
    if (activeId == null) return null;
    final plans = await loadAll();
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
    final plans  = await loadAll();
    plans.removeWhere((p) => p.id == planId);
    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));

    // If deleted plan was active, switch to the last one (or clear)
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
  }
}