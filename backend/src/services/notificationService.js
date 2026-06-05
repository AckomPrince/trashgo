const admin = require('../config/firebase');
const db    = require('../config/database');
const logger = require('../config/logger');

/**
 * Send a single FCM push notification.
 */
async function sendPush(fcmToken, { title, body, data = {} }) {
  if (!fcmToken) return;
  try {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high' },
      apns:    { payload: { aps: { sound: 'default' } } },
    };
    const result = await admin.messaging().send(message);
    logger.debug(`FCM sent: ${result}`);
  } catch (err) {
    logger.warn(`FCM send failed for token ${fcmToken?.slice(0, 20)}: ${err.message}`);
  }
}

/**
 * Send push and log to notifications table.
 */
async function notify(userId, { title, body, data = {} }) {
  try {
    const { rows } = await db.query('SELECT fcm_token FROM users WHERE id=$1', [userId]);
    const fcmToken = rows[0]?.fcm_token;

    // Log in DB
    await db.query(
      `INSERT INTO notifications (user_id, title, body, data) VALUES ($1,$2,$3,$4)`,
      [userId, title, body, JSON.stringify(data)]
    );

    if (fcmToken) await sendPush(fcmToken, { title, body, data });
  } catch (err) {
    logger.error('notify() error:', err.message);
  }
}

module.exports = { sendPush, notify };
