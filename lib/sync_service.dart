import 'training_plan_model.dart';
import 'plan_storage.dart';
import 'api_service.dart';
import 'auth_storage.dart';

// ─────────────────────────────────────────────
//  SyncService
//
//  Push: called after every local save.
//        Sends the plan to the server.
//        No-op if guest (no token).
//
//  Pull: called when SelectTrainingPlanScreen opens.
//        Fetches server stubs (planId + updatedAt).
//        For each server plan:
//          - Not in local storage → download and save
//          - In local storage but server is newer → download and overwrite
//          - Local is newer or equal → skip (local wins)
//        No-op if guest (no token).
//
//  Delete: mirrors local deletion to server.
//          No-op if guest (no token).
// ─────────────────────────────────────────────

class SyncService {

  // ── Push one plan to the server ───────────────────────────────────────────
  // Called after every PlanStorage.save().
  static Future<void> pushPlan(TrainingPlan plan) async {
    final token = await AuthStorage.getToken();
    if (token == null) return; // guest — skip

    await ApiService.upsertPlan(token, plan.id, plan.toJsonString());
  }

  // ── Pull plans from server ────────────────────────────────────────────────
  // Returns number of plans that were newly saved or updated locally.
  static Future<int> pullFromServer() async {
    final token  = await AuthStorage.getToken();
    if (token == null) return 0; // guest — skip

    final userId = await AuthStorage.getUserId();
    if (userId == null) return 0;

    // Step 1: get all plan stubs for this user from the server.
    final stubs = await ApiService.listPlanStubs(token);
    if (stubs.isEmpty) return 0;

    // Step 2: load local plans for comparison.
    final localPlans = await PlanStorage.loadAllUnfiltered();
    final localById  = { for (final p in localPlans) p.id: p };

    int changed = 0;

    for (final stub in stubs) {
      final planId        = stub['planId']    as String?;
      final serverUpdated = stub['updatedAt'] as String?;
      if (planId == null || serverUpdated == null) continue;

      DateTime serverTime;
      try {
        serverTime = DateTime.parse(serverUpdated).toUtc();
      } catch (_) { continue; }

      final local = localById[planId];

      // Decide whether to pull:
      //   - Plan doesn't exist locally → pull
      //   - Server updatedAt is after local lastModifiedAt → pull (server is newer)
      //   - Local is same or newer → skip
      final shouldPull = local == null ||
          serverTime.isAfter(local.lastModifiedAt);

      if (!shouldPull) continue;

      // Step 3: download the full plan.
      final data     = await ApiService.getPlan(token, planId);
      final planJson = data?['planJson'] as String?;
      if (planJson == null) continue;

      try {
        final raw  = TrainingPlan.fromJsonString(planJson);
        final plan = TrainingPlan(
          id:                    raw.id,
          profile:               raw.profile,
          startDate:             raw.startDate,
          tim:                   raw.tim,
          workouts:              raw.workouts,
          intensityDeltaSeconds: raw.intensityDeltaSeconds,
          setsDelta:             raw.setsDelta,
          totalSteps:            raw.totalSteps,
          ownerId:               userId,
          lastModifiedAt:        serverTime, // use server time so next sync sees them as equal
        );
        await PlanStorage.saveWithoutActivating(plan);
        changed++;
      } catch (_) {
        continue; // skip corrupt plan
      }
    }

    return changed;
  }

  // ── Mirror deletion to server ─────────────────────────────────────────────
  static Future<void> deletePlan(String planId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return; // guest — skip
    await ApiService.deletePlan(token, planId);
  }
}