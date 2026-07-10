const db = require('../config/database');
const { getIO } = require('./socketService');
const { sendPush } = require('./notificationService');

/**
 * Haversine distance in km between two lat/lng points.
 */
function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * FIX: Previously loaded ALL online riders into Node.js memory before filtering
 * by distance. With thousands of riders this OOMs or causes severe latency.
 *
 * Solution: apply a latitude/longitude bounding-box filter directly in SQL
 * (cheap indexed range scan), then do exact Haversine only on the small
 * candidate set that survives the box filter.
 *
 * 1° lat  ≈ 111 km → for maxKm we need ±(maxKm/111) degrees latitude.
 * 1° lng  ≈ 111 km × cos(lat) → we use cos(0) = 1 as a conservative over-
 *            estimate so we never miss a rider near the edge.
 */
async function findNearbyRiders(pickupLat, pickupLng, maxKm = 10, limit = 5) {
  // FIX: pg returns numeric columns as strings; coerce to float before arithmetic
  // so the `+` delta operation does numeric addition instead of string concat.
  const lat = parseFloat(pickupLat);
  const lng = parseFloat(pickupLng);

  const latDelta = maxKm / 111.0;
  const lngDelta = maxKm / (111.0 * Math.cos((lat * Math.PI) / 180));

  const { rows } = await db.query(
    `SELECT u.id, u.full_name, u.phone, u.fcm_token,
            rp.current_lat, rp.current_lng, rp.vehicle_type, rp.vehicle_plate,
            rp.rating_avg, rp.completed_count, rp.accepted_count
     FROM users u
     JOIN rider_profiles rp ON rp.user_id = u.id
     WHERE rp.is_online = TRUE
       AND rp.status = 'approved'
       AND rp.current_lat IS NOT NULL
       AND rp.current_lng IS NOT NULL
       AND rp.current_lat  BETWEEN $1 AND $2
       AND rp.current_lng  BETWEEN $3 AND $4`,
    [
      lat - latDelta, lat + latDelta,
      lng - lngDelta, lng + lngDelta,
    ]
  );

  // Exact Haversine on the already-small bounding-box subset.
  // S3 (#4): rank by distance first, then break ties with the rider's rating
  // (higher rated wins) so better riders are offered marginally-equal jobs first.
  return rows
    .map((r) => ({
      ...r,
      distance_km: haversine(pickupLat, pickupLng, r.current_lat, r.current_lng),
    }))
    .filter((r) => r.distance_km <= maxKm)
    .sort((a, b) => {
      if (Math.abs(a.distance_km - b.distance_km) > 0.25) return a.distance_km - b.distance_km;
      return (parseFloat(b.rating_avg) || 0) - (parseFloat(a.rating_avg) || 0);
    })
    .slice(0, limit);
}

/**
 * Broadcast a new order to nearby riders via Socket.IO + FCM.
 */
async function broadcastOrderToRiders(order) {
  const riders = await findNearbyRiders(order.pickup_lat, order.pickup_lng);
  if (!riders.length) return 0;

  const io = getIO();
  const ttl = parseInt(process.env.OFFER_TTL_SECONDS || '60', 10);

  for (const rider of riders) {
    // S3 (#4): persist the offer so the rider can decline it, it can expire,
    // and accepting can close sibling offers. Idempotent per (order, rider).
    await db.query(
      `INSERT INTO order_offers (order_id, rider_id, status, expires_at)
       VALUES ($1, $2, 'offered', NOW() + ($3 || ' seconds')::interval)
       ON CONFLICT (order_id, rider_id) DO NOTHING`,
      [order.id, rider.id, String(ttl)]
    );

    io.to(`rider:${rider.id}`).emit('new_order_request', {
      order_id:       order.id,
      pickup_address: order.pickup_address,
      waste_type:     order.waste_type,
      pickup_lat:     order.pickup_lat,
      pickup_lng:     order.pickup_lng,
      distance_km:    rider.distance_km.toFixed(1),
      expires_in:     ttl,
    });

    if (rider.fcm_token) {
      await sendPush(rider.fcm_token, {
        title: '🗑️ New Pickup Request',
        body: `${rider.distance_km.toFixed(1)} km away — ${order.waste_type} waste`,
        data: { type: 'new_order', order_id: order.id },
      });
    }
  }

  return riders.length;
}

module.exports = { findNearbyRiders, broadcastOrderToRiders };
