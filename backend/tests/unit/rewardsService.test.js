jest.mock('../../src/config/database');
jest.mock('../../src/services/notificationService');

const db = require('../../src/config/database');
const { notify } = require('../../src/services/notificationService');
const { awardPoints, requestRedemption } = require('../../src/services/rewardsService');

function makeClient() {
  return { query: jest.fn().mockResolvedValue({ rows: [] }), release: jest.fn() };
}

describe('rewardsService.awardPoints', () => {
  test('commits the transaction, records the ledger entry and notifies the customer', async () => {
    const client = makeClient();
    client.query.mockImplementation((text) => {
      if (/SELECT balance/.test(text)) return Promise.resolve({ rows: [{ balance: 150 }] });
      return Promise.resolve({ rows: [] });
    });
    db.getClient.mockResolvedValue(client);

    const balance = await awardPoints('cust-1', 'order-1', 50);

    expect(balance).toBe(150);
    const executed = client.query.mock.calls.map((c) => c[0]);
    expect(executed[0]).toBe('BEGIN');
    expect(executed).toContain('COMMIT');
    expect(executed).not.toContain('ROLLBACK');
    expect(client.release).toHaveBeenCalled();
    expect(notify).toHaveBeenCalledWith('cust-1', expect.objectContaining({
      data: expect.objectContaining({ type: 'points_earned' }),
    }));
  });

  test('rolls back and rethrows when a write fails', async () => {
    const client = makeClient();
    client.query.mockImplementation((text) => {
      if (/INSERT INTO points_transactions/.test(text)) return Promise.reject(new Error('boom'));
      if (/SELECT balance/.test(text)) return Promise.resolve({ rows: [{ balance: 10 }] });
      return Promise.resolve({ rows: [] });
    });
    db.getClient.mockResolvedValue(client);

    await expect(awardPoints('cust-1', 'order-1', 50)).rejects.toThrow('boom');
    const executed = client.query.mock.calls.map((c) => c[0]);
    expect(executed).toContain('ROLLBACK');
    expect(executed).not.toContain('COMMIT');
    expect(client.release).toHaveBeenCalled();
    expect(notify).not.toHaveBeenCalled();
  });
});

describe('rewardsService.requestRedemption', () => {
  test('rejects when below the minimum redemption threshold', async () => {
    await expect(
      requestRedemption('u1', { points: 100, payoutMethod: 'momo', payoutAccount: '024...' })
    ).rejects.toThrow('Minimum redemption is 500 points');
    expect(db.getClient).not.toHaveBeenCalled();
  });

  test('rejects when the wallet balance is insufficient', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: 300 }] });
    await expect(
      requestRedemption('u1', { points: 600, payoutMethod: 'momo', payoutAccount: '024...' })
    ).rejects.toThrow('Insufficient points balance');
    expect(db.getClient).not.toHaveBeenCalled();
  });

  test('deducts points, records a redemption and returns the cash value', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: 1000 }] }); // pre-check balance
    const client = makeClient();
    client.query.mockImplementation((text) => {
      if (/SELECT balance/.test(text)) return Promise.resolve({ rows: [{ balance: 400 }] });
      if (/INSERT INTO redemptions/.test(text)) return Promise.resolve({ rows: [{ id: 'red-1' }] });
      return Promise.resolve({ rows: [] });
    });
    db.getClient.mockResolvedValue(client);

    const result = await requestRedemption('u1', { points: 600, payoutMethod: 'momo', payoutAccount: '024...' });

    expect(result).toEqual({ redemption_id: 'red-1', cash_value: 6.0 }); // 600 / 100
    const executed = client.query.mock.calls.map((c) => c[0]);
    expect(executed[0]).toBe('BEGIN');
    expect(executed).toContain('COMMIT');
    expect(notify).toHaveBeenCalledWith('u1', expect.objectContaining({
      data: expect.objectContaining({ type: 'redemption_requested' }),
    }));
  });
});
