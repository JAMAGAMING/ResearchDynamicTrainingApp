// src/routes/auth.js
//
//  POST /auth/register   — create account
//  POST /auth/login      — returns JWT
//  POST /auth/reset-password — change password (requires current password)
//  GET  /auth/me         — returns username + fullName (requires token)

const express    = require('express');
const bcrypt     = require('bcryptjs');
const jwt        = require('jsonwebtoken');
const prisma     = require('../prisma');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();

// ── Register ──────────────────────────────────
router.post('/register', async (req, res) => {
  const { username, fullName, password } = req.body;

  if (!username || !fullName || !password) {
    return res.status(400).json({ error: 'username, fullName, and password are required' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const exists = await prisma.user.findUnique({ where: { username } });
  if (exists) {
    return res.status(409).json({ error: 'Username already taken' });
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const user = await prisma.user.create({
    data: { username, fullName, passwordHash },
  });

  const token = signToken(user.id);
  return res.status(201).json({
    token,
    user: { id: user.id, username: user.username, fullName: user.fullName },
  });
});

// ── Login ─────────────────────────────────────
router.post('/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'username and password are required' });
  }

  const user = await prisma.user.findUnique({ where: { username } });
  if (!user) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  const token = signToken(user.id);
  return res.json({
    token,
    user: { id: user.id, username: user.username, fullName: user.fullName },
  });
});

// ── Reset Password ────────────────────────────
router.post('/reset-password', requireAuth, async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'currentPassword and newPassword are required' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters' });
  }

  const user = await prisma.user.findUnique({ where: { id: req.userId } });
  const valid = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!valid) {
    return res.status(401).json({ error: 'Current password is incorrect' });
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await prisma.user.update({
    where: { id: req.userId },
    data:  { passwordHash },
  });

  return res.json({ ok: true });
});

// ── Get profile ───────────────────────────────
router.get('/me', requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where:  { id: req.userId },
    select: { id: true, username: true, fullName: true, createdAt: true },
  });
  if (!user) return res.status(404).json({ error: 'User not found' });
  return res.json(user);
});

// ── Helper ────────────────────────────────────
function signToken(userId) {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '30d' },
  );
}

module.exports = router;
