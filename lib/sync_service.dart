import 'training_plan_model.dart';
import 'plan_storage.dart';
import 'api_service.dart';
import 'auth_storage.dart';

// ─────────────────────────────────────────────
//  SyncService
//
//  Implements the sync rules:
//
//  Rule 1 — Full sync (called when SelectTrainingPlanScreen opens):
//    a) Push every local plan to the server (upsert).
//       Local is always the source of truth.
//    b) Pull any server plan whose planId doesn't exist locally yet
//       and save it locally. (Never overwrites existing local plans.)
//
//  Rule 2 — Push on modify (called after every PlanStorage.save):
//    Upload the modified plan to PUT /plans/:planId.
//
//  Rule 3 — Delete mirror (called after PlanStorage.delete):
//    Fire-and-forget DELETE /plans/:planId.
//
//  All methods are fire-and-forget safe: they return false / quietly
//  on network failure so the app works fully offline.
// ─────────────────────────────────────────────

class SyncService {
  // ── Full bidirectional sync ───────────────────
  //
  // Returns the number of plans pulled from the server (0 if offline).
  // The caller can use this to know if _loadPlans() should be called again.
  static Future<int> fullSync() async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;

    // ── Step 1: Push all local plans ─────────────
    final localPlans = await PlanStorage.loadAll();
    if (localPlans.isNotEmpty) {
      final batch = localPlans
          .map((p) => {'planId': p.id, 'planJson': p.toJsonString()})
          .toList();
      await ApiService.batchUpsertPlans(token, batch);
    }

    // ── Step 2: Pull new plans from server ────────
    final stubs = await ApiService.listPlanStubs(token);
    if (stubs.isEmpty) return 0;

    final localIds = localPlans.map((p) => p.id).toSet();
    int pulled = 0;

    for (final stub in stubs) {
      final serverId = stub['planId'] as String?;
      if (serverId == null) continue;
      if (localIds.contains(serverId)) continue; // already have it locally

      // Fetch the full plan and save locally.
      final data = await ApiService.getPlan(token, serverId);
      if (data == null) continue;

      final planJson = data['planJson'] as String?;
      if (planJson == null) continue;

      try {
        final plan = TrainingPlan.fromJsonString(planJson);
        // Save without marking it active — let the user choose.
        await PlanStorage.saveWithoutActivating(plan);
        pulled++;
      } catch (_) {
        // Corrupt/incompatible plan — skip silently.
      }
    }

    return pulled;
  }

  // ── Push single plan after any local modification ──
  static Future<void> pushPlan(TrainingPlan plan) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.upsertPlan(token, plan.id, plan.toJsonString());
  }

  // ── Mirror a local deletion to the server ─────
  static Future<void> deletePlan(String planId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.deletePlan(token, planId); // fire-and-forget
  }
}
