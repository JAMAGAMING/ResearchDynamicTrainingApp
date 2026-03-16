// src/routes/plans.js
//
//  All routes require a valid Bearer token.
//
//  GET    /plans              — list all plan stubs for this user
//                               (returns planId + updatedAt, NOT full JSON)
//  GET    /plans/:planId      — get full JSON for a single plan
//  PUT    /plans/:planId      — upsert (create or overwrite) a plan
//  DELETE /plans/:planId      — delete a plan
//  POST   /plans/batch        — upsert many plans in one request (used on first sync)

const express     = require('express');
const prisma      = require('../prisma');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();
router.use(requireAuth);

// ── List plan stubs ───────────────────────────
// Returns only planId + updatedAt so the app can decide which plans to pull
// without downloading every full JSON blob on every sync.
router.get('/', async (req, res) => {
  const plans = await prisma.trainingPlan.findMany({
    where:  { userId: req.userId },
    select: { planId: true, updatedAt: true },
  });
  return res.json(plans);
});

// ── Get single plan ───────────────────────────
router.get('/:planId', async (req, res) => {
  const plan = await prisma.trainingPlan.findUnique({
    where: { userId_planId: { userId: req.userId, planId: req.params.planId } },
  });
  if (!plan) return res.status(404).json({ error: 'Plan not found' });
  return res.json({ planId: plan.planId, planJson: plan.planJson, updatedAt: plan.updatedAt });
});

// ── Upsert single plan ────────────────────────
// The app calls this after every local save (create / modify / complete day / etc.)
router.put('/:planId', async (req, res) => {
  const { planJson } = req.body;

  if (!planJson || typeof planJson !== 'string') {
    return res.status(400).json({ error: 'planJson (string) is required' });
  }

  const plan = await prisma.trainingPlan.upsert({
    where:  { userId_planId: { userId: req.userId, planId: req.params.planId } },
    update: { planJson },
    create: { planId: req.params.planId, userId: req.userId, planJson },
  });

  return res.json({ planId: plan.planId, updatedAt: plan.updatedAt });
});

// ── Delete plan ───────────────────────────────
router.delete('/:planId', async (req, res) => {
  try {
    await prisma.trainingPlan.delete({
      where: { userId_planId: { userId: req.userId, planId: req.params.planId } },
    });
  } catch (_) {
    // Already deleted or never existed — not an error from the app's perspective.
  }
  return res.json({ ok: true });
});

// ── Batch upsert ──────────────────────────────
// Used during initial sync: the app pushes all local plans it knows
// the server doesn't have yet in one shot.
//   Body: { plans: [{ planId: string, planJson: string }, ...] }
router.post('/batch', async (req, res) => {
  const { plans } = req.body;

  if (!Array.isArray(plans)) {
    return res.status(400).json({ error: 'plans array is required' });
  }

  // Upsert each plan. Run concurrently but cap parallelism to avoid
  // hammering SQLite with too many writes at once.
  const results = [];
  for (const item of plans) {
    if (!item.planId || !item.planJson) continue;
    const saved = await prisma.trainingPlan.upsert({
      where:  { userId_planId: { userId: req.userId, planId: item.planId } },
      update: { planJson: item.planJson },
      create: { planId: item.planId, userId: req.userId, planJson: item.planJson },
    });
    results.push({ planId: saved.planId, updatedAt: saved.updatedAt });
  }

  return res.json({ saved: results.length });
});

module.exports = router;
