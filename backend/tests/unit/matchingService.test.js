jest.mock('../../src/config/database');
jest.mock('../../src/services/socketService');
jest.mock('../../src/services/notificationService');

const db = require('../../src/config/database');
const { getIO } = require('../../src/services/socketService');
const { sendPush } = require('../../src/services/notificationService');
const { findNearbyRiders, broadcastOrderToRiders } = require('../../src/services/matchingService');

describe('matchingService.findNearbyRiders', () => {
  const pickupLat = 5.6;
  const pickupLng = -0.2;

  test('keeps riders within maxKm, sorts nearest-first, drops far ones', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { id: 'r-far',   full_name: 'Far',   current_lat: 6.60, current_lng: -0.20 }, // ~111 km
        { id: 'r-near',  full_name: 'Near',  current_lat: 5.60, current_lng: -0.20 }, // ~0 km
        { id: 'r-mid',   full_name: 'Mid',   current_lat: 5.65, current_lng: -0.20 }, // ~5.5 km
      ],
    });

    const result = await findNearbyRiders(pickupLat, pickupLng, 10, 5);

    expect(result.map((r) => r.id)).toEqual(['r-near', 'r-mid']); // far one filtered out
    expect(result[0].distance_km).toBeLessThan(result[1].distance_km);
    expect(result[0].distance_km).toBeCloseTo(0, 1);
    expect(result[1].distance_km).toBeCloseTo(5.56, 0);
  });

  test('honours the limit parameter', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { id: 'a', current_lat: 5.601, current_lng: -0.20 },
        { id: 'b', current_lat: 5.602, current_lng: -0.20 },
        { id: 'c', current_lat: 5.603, current_lng: -0.20 },
      ],
    });
    const result = await findNearbyRiders(pickupLat, pickupLng, 10, 2);
    expect(result).toHaveLength(2);
  });

  test('builds a bounding box query from float-coerced coordinates', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    await findNearbyRiders('5.6', '-0.2', 10, 5);

    const [, params] = db.query.mock.calls[0];
    // params = [latLow, latHigh, lngLow, lngHigh]
    expect(params[0]).toBeCloseTo(5.6 - 10 / 111, 4);
    expect(params[1]).toBeCloseTo(5.6 + 10 / 111, 4);
    expect(typeof params[0]).toBe('number');
  });

  test('returns empty array when no riders in the box', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    expect(await findNearbyRiders(pickupLat, pickupLng)).toEqual([]);
  });
});

describe('matchingService.broadcastOrderToRiders', () => {
  test('emits socket events and pushes FCM only to riders with a token', async () => {
    db.query.mockResolvedValue({ rows: [] }); // default for the per-rider offer INSERTs
    db.query.mockResolvedValueOnce({
      rows: [
        { id: 'r1', current_lat: 5.60, current_lng: -0.20, fcm_token: 'tok-1' },
        { id: 'r2', current_lat: 5.61, current_lng: -0.20, fcm_token: null },
      ],
    });

    const emit = jest.fn();
    getIO.mockReturnValue({ to: jest.fn(() => ({ emit })) });

    const order = {
      id: 'order-1',
      pickup_address: '12 Ring Rd',
      waste_type: 'general',
      pickup_lat: 5.6,
      pickup_lng: -0.2,
    };

    const count = await broadcastOrderToRiders(order);

    expect(count).toBe(2);
    expect(emit).toHaveBeenCalledTimes(2);
    expect(emit).toHaveBeenCalledWith('new_order_request', expect.objectContaining({ order_id: 'order-1' }));
    expect(sendPush).toHaveBeenCalledTimes(1); // only r1 has an fcm_token
    expect(sendPush).toHaveBeenCalledWith('tok-1', expect.objectContaining({ data: expect.objectContaining({ order_id: 'order-1' }) }));
  });

  test('returns 0 and skips socket/push when no riders are nearby', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    const count = await broadcastOrderToRiders({ id: 'o', pickup_lat: 5.6, pickup_lng: -0.2 });
    expect(count).toBe(0);
    expect(getIO).not.toHaveBeenCalled();
    expect(sendPush).not.toHaveBeenCalled();
  });
});
