require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const db = require('./src/config/database');
const { initSocket } = require('./src/services/socketService');
const { scheduleRewardExpiry } = require('./src/services/rewardsService');
const logger = require('./src/config/logger');

// ── Routes ────────────────────────────────────────
const authRoutes    = require('./src/routes/auth');
const orderRoutes   = require('./src/routes/orders');
const riderRoutes   = require('./src/routes/riders');
const paymentRoutes = require('./src/routes/payments');
const rewardRoutes  = require('./src/routes/rewards');
const adminRoutes   = require('./src/routes/admin');
const { errorHandler } = require('./src/middleware/errorHandler');

const app    = express();
const server = http.createServer(app);

// ── Socket.IO ─────────────────────────────────────
initSocket(server);

// ── Middleware ────────────────────────────────────
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',');
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || allowedOrigins.includes(origin)) cb(null, true);
    else cb(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
app.use(helmet());
app.use(morgan('combined', { stream: { write: msg => logger.info(msg.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
app.use('/api/v1/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 30, message: 'Too many auth requests' }));
app.use('/api/v1', rateLimit({ windowMs: 60 * 1000, max: 200 }));

// ── Health ────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected', ts: new Date().toISOString() });
  } catch (e) {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

// ── API Routes ────────────────────────────────────
app.use('/api/v1/auth',     authRoutes);
app.use('/api/v1/orders',   orderRoutes);
app.use('/api/v1/riders',   riderRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/rewards',  rewardRoutes);
app.use('/api/v1/admin',    adminRoutes);

app.use(errorHandler);

// ── Cron jobs ─────────────────────────────────────
scheduleRewardExpiry();

// ── Start ─────────────────────────────────────────
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => logger.info(`TrashGo API running on port ${PORT}`));

module.exports = { app, server };
