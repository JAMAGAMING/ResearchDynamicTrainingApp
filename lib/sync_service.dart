import 'training_plan_model.dart';
import 'plan_storage.dart';
import 'api_service.dart';
import 'auth_storage.dart';

// ─────────────────────────────────────────────
//  SyncService
//
//  Conflict resolution rule (timestamp-based):
//    • Every TrainingPlan carries a lastModifiedAt (UTC) stamped
//      by PlanStorage.save() on every local write.
//    • The server row carries its own updatedAt (set by Prisma
//      on every upsert).
//    • Whichever copy is NEWER wins:
//
//        local.lastModifiedAt > server.updatedAt  → push local to server
//        server.updatedAt > local.lastModifiedAt  → pull server, overwrite local
//        timestamps equal                         → already in sync, skip
//        plan missing on server                   → push local
//        plan missing locally                     → pull from server
//
//  This means:
//    • Device B modifies a plan offline → its lastModifiedAt advances.
//    • Device B goes online and syncs → local is newer → pushes to server.
//    • Device A syncs next → server is now newer → pulls Device B's version.
//
//  Full sync flow (triggered on SelectTrainingPlanScreen open / manual refresh):
//    1. Fetch all server stubs (planId + updatedAt) in one request.
//    2. Compare each local plan against its server counterpart.
//    3. Pull any server-only plans that don't exist locally.
//
//  Push on modify: always push — local was just saved so it is newest.
//  Delete mirror:  fire-and-forget DELETE on server.
//
//  All methods degrade gracefully when offline.
// ─────────────────────────────────────────────

class SyncService {

  // ── Full bidirectional sync ───────────────────
  //
  // Returns the number of plans that were pulled from the server and
  // saved locally (so the caller knows whether to reload the list).
  static Future<int> fullSync() async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;

    // ── Step 1: Get all server stubs in one request ──
    final stubs = await ApiService.listPlanStubs(token);

    // Build planId → server updatedAt lookup.
    final serverTimestamps = <String, DateTime>{};
    for (final stub in stubs) {
      final id  = stub['planId']    as String?;
      final raw = stub['updatedAt'] as String?;
      if (id == null || raw == null) continue;
      try {
        serverTimestamps[id] = DateTime.parse(raw).toUtc();
      } catch (_) {}
    }

    final localPlans = await PlanStorage.loadAll();
    final localIds   = { for (final p in localPlans) p.id };
    int locallyChanged = 0;

    // ── Step 2: Reconcile each local plan ────────
    for (final plan in localPlans) {
      final serverTime = serverTimestamps[plan.id];

      if (serverTime == null) {
        // Not on server yet → push it.
        await ApiService.upsertPlan(token, plan.id, plan.toJsonString());
        continue;
      }

      final localTime = plan.lastModifiedAt;

      if (localTime.isAfter(serverTime)) {
        // Local is newer → push to server.
        await ApiService.upsertPlan(token, plan.id, plan.toJsonString());
      } else if (serverTime.isAfter(localTime)) {
        // Server is newer → pull and overwrite local silently.
        final pulled = await _pullAndSave(token, plan.id);
        if (pulled) locallyChanged++;
      }
      // If equal → already in sync, nothing to do.
    }

    // ── Step 3: Pull server-only plans ───────────
    for (final serverId in serverTimestamps.keys) {
      if (!localIds.contains(serverId)) {
        final pulled = await _pullAndSave(token, serverId);
        if (pulled) locallyChanged++;
      }
    }

    return locallyChanged;
  }

  // ── Push single plan after any local modification ──
  // Local was just saved so it is by definition the newest copy.
  // No timestamp comparison needed here.
  static Future<void> pushPlan(TrainingPlan plan) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.upsertPlan(token, plan.id, plan.toJsonString());
  }

  // ── Mirror a local deletion to the server ─────
  static Future<void> deletePlan(String planId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.deletePlan(token, planId);
  }

  // ── Fetch a plan from server and save locally ──
  //
  // Uses saveWithoutActivating so:
  //   • The active plan pointer is not changed.
  //   • No further push back to the server is triggered.
  //
  // The server's updatedAt is stored as the local lastModifiedAt so
  // the next sync sees them as equal and skips it.
  static Future<bool> _pullAndSave(String token, String planId) async {
    final data = await ApiService.getPlan(token, planId);
    if (data == null) return false;

    final planJson        = data['planJson']   as String?;
    final serverUpdatedAt = data['updatedAt']  as String?;
    if (planJson == null) return false;

    DateTime? serverTime;
    if (serverUpdatedAt != null) {
      try { serverTime = DateTime.parse(serverUpdatedAt).toUtc(); } catch (_) {}
    }

    try {
      final raw = TrainingPlan.fromJsonString(planJson);
      // Reconstruct with server's timestamp so local lastModifiedAt == server
      // updatedAt after the pull — prevents an immediate push-back on next sync.
      final plan = TrainingPlan(
        id:                    raw.id,
        profile:               raw.profile,
        startDate:             raw.startDate,
        tim:                   raw.tim,
        workouts:              raw.workouts,
        intensityDeltaSeconds: raw.intensityDeltaSeconds,
        setsDelta:             raw.setsDelta,
        lastModifiedAt:        serverTime ?? raw.lastModifiedAt,
      );
      await PlanStorage.saveWithoutActivating(plan);
      return true;
    } catch (_) {
      return false; // corrupt or incompatible plan — skip silently
    }
  }
}