const db = require('../config/database');

/**
 * Returns the configured price for a given waste size + type.
 * Falls back to 'general' if no specific type config exists.
 */
async function getPrice(wasteSize, wasteType = 'general') {
  const { rows } = await db.query(
    `SELECT price, currency FROM pricing_config
     WHERE waste_size=$1 AND waste_type=$2 AND is_active=TRUE
     LIMIT 1`,
    [wasteSize, wasteType]
  );

  if (rows.length) return rows[0];

  // fallback to general
  const { rows: fallback } = await db.query(
    `SELECT price, currency FROM pricing_config
     WHERE waste_size=$1 AND waste_type='general' AND is_active=TRUE
     LIMIT 1`,
    [wasteSize]
  );
  return fallback[0] || { price: 5.00, currency: 'GHS' };
}

/**
 * Calculate points earned for a completed order.
 */
function calculatePoints({ wasteType, wasteSize }) {
  const base = parseInt(process.env.POINTS_PER_PICKUP || '50');
  const sizeBonus = { small: 0, medium: 20, large: 40 }[wasteSize] || 0;
  const recyclableMultiplier = wasteType === 'recyclable'
    ? parseFloat(process.env.RECYCLABLE_MULTIPLIER || '1.5') : 1.0;

  return Math.round((base + sizeBonus) * recyclableMultiplier);
}

module.exports = { getPrice, calculatePoints };
