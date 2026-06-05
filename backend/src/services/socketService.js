const { Server } = require('socket.io');
const jwt    = require('jsonwebtoken');
const db     = require('../config/database');
const logger = require('../config/logger');

let io;

function initSocket(server) {
  // FIX: CORS origin from environment variable — not '*' in production
  const allowedOrigins = process.env.SOCKET_ALLOWED_ORIGINS
    ? process.env.SOCKET_ALLOWED_ORIGINS.split(',').map((o) => o.trim())
    : '*'; // fallback keeps dev working when env var is unset

  io = new Server(server, {
    cors: { origin: allowedOrigins, methods: ['GET', 'POST'] },
    transports: ['websocket', 'polling'],
  });

  // Auth middleware — validate JWT on every socket connection
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) return next(new Error('Authentication required'));
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const { rows } = await db.query('SELECT id, role FROM users WHERE id=$1', [decoded.userId]);
      if (!rows.length) return next(new Error('User not found'));
      socket.user = rows[0];
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const user = socket.user;
    logger.info(`Socket connected: ${user.id} (${user.role})`);

    // Join personal room
    socket.join(`user:${user.id}`);
    if (user.role === 'rider') socket.join(`rider:${user.id}`);

    // Rider: stream current GPS location
    socket.on('rider:location', async ({ lat, lng }) => {
      if (user.role !== 'rider') return;
      await db.query(
        `UPDATE rider_profiles SET current_lat=$1, current_lng=$2, last_seen_at=NOW() WHERE user_id=$3`,
        [lat, lng, user.id]
      );
      socket.to(`tracking_rider:${user.id}`).emit('rider:location_update', { lat, lng });
    });

    // Customer: subscribe to a rider's real-time location.
    // FIX: only allow if the customer has an active order assigned to that rider.
    socket.on('track:rider', async ({ rider_id }) => {
      if (user.role !== 'customer') return;

      try {
        const { rows } = await db.query(
          `SELECT id FROM orders
           WHERE customer_id=$1 AND rider_id=$2
             AND status NOT IN ('completed', 'cancelled')
           LIMIT 1`,
          [user.id, rider_id]
        );

        if (!rows.length) {
          socket.emit('track:error', { message: 'No active order with this rider' });
          return;
        }

        socket.join(`tracking_rider:${rider_id}`);
      } catch (err) {
        logger.error('track:rider DB error', err);
      }
    });

    // Rider: go online / offline
    socket.on('rider:availability', async ({ online }) => {
      if (user.role !== 'rider') return;
      await db.query(
        `UPDATE rider_profiles SET is_online=$1, last_seen_at=NOW() WHERE user_id=$2`,
        [!!online, user.id]
      );
      socket.emit('rider:availability_updated', { online: !!online });
    });

    socket.on('disconnect', () => {
      logger.info(`Socket disconnected: ${user.id}`);
    });
  });

  logger.info('Socket.IO initialised');
  return io;
}

function getIO() {
  if (!io) throw new Error('Socket.IO not initialised');
  return io;
}

/**
 * Emit an event to a specific user's personal room.
 * Safe to call even before socket server is ready (emits are a no-op).
 */
function emitToUser(userId, event, data) {
  if (!io) return;
  io.to(`user:${userId}`).emit(event, data);
}

module.exports = { initSocket, getIO, emitToUser };
