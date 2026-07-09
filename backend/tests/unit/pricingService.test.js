jest.mock('../../src/config/database');

const db = require('../../src/config/database');
const { calculatePoints, getPrice } = require('../../src/services/pricingService');

describe('pricingService.calculatePoints', () => {
  test('base points for a small general pickup (50 + 0) * 1.0', () => {
    expect(calculatePoints({ wasteType: 'general', wasteSize: 'small' })).toBe(50);
  });

  test('medium adds a 20pt size bonus', () => {
    expect(calculatePoints({ wasteType: 'general', wasteSize: 'medium' })).toBe(70);
  });

  test('large adds a 40pt size bonus', () => {
    expect(calculatePoints({ wasteType: 'general', wasteSize: 'large' })).toBe(90);
  });

  test('recyclable applies the 1.5x multiplier and rounds', () => {
    // (50 + 20) * 1.5 = 105
    expect(calculatePoints({ wasteType: 'recyclable', wasteSize: 'medium' })).toBe(105);
    // (50 + 0) * 1.5 = 75
    expect(calculatePoints({ wasteType: 'recyclable', wasteSize: 'small' })).toBe(75);
    // (50 + 40) * 1.5 = 135
    expect(calculatePoints({ wasteType: 'recyclable', wasteSize: 'large' })).toBe(135);
  });

  test('unknown waste size contributes no bonus', () => {
    expect(calculatePoints({ wasteType: 'general', wasteSize: 'gigantic' })).toBe(50);
  });

  test('honours env overrides for base points and multiplier', () => {
    const prevBase = process.env.POINTS_PER_PICKUP;
    const prevMult = process.env.RECYCLABLE_MULTIPLIER;
    process.env.POINTS_PER_PICKUP = '100';
    process.env.RECYCLABLE_MULTIPLIER = '2';
    // (100 + 40) * 2 = 280
    expect(calculatePoints({ wasteType: 'recyclable', wasteSize: 'large' })).toBe(280);
    process.env.POINTS_PER_PICKUP = prevBase;
    process.env.RECYCLABLE_MULTIPLIER = prevMult;
  });
});

describe('pricingService.getPrice', () => {
  test('returns the exact type match when one exists', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ price: '12.50', currency: 'GHS' }] });
    const price = await getPrice('large', 'recyclable');
    expect(price).toEqual({ price: '12.50', currency: 'GHS' });
    expect(db.query).toHaveBeenCalledTimes(1);
  });

  test('falls back to the general config when no type match', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })                                   // no specific match
      .mockResolvedValueOnce({ rows: [{ price: '8.00', currency: 'GHS' }] }); // general fallback
    const price = await getPrice('medium', 'hazardous');
    expect(price).toEqual({ price: '8.00', currency: 'GHS' });
    expect(db.query).toHaveBeenCalledTimes(2);
  });

  test('falls back to a hardcoded default when nothing is configured', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });
    const price = await getPrice('small', 'general');
    expect(price).toEqual({ price: 5.0, currency: 'GHS' });
  });
});
