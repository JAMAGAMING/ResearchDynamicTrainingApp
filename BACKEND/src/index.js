// src/index.js
require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const authRoutes = require('./routes/auth');
const planRoutes = require('./routes/plans');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ────────────────────────────────
app.use(cors());
app.use(express.json({ limit: '10mb' })); // plans can be large JSON blobs

// ── Routes ────────────────────────────────────
app.use('/auth',  authRoutes);
app.use('/plans', planRoutes);

// ── Health check ──────────────────────────────
app.get('/health', (_, res) => res.json({ ok: true }));

// ── Global error handler ──────────────────────
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Training app server running on port ${PORT}`);
});
