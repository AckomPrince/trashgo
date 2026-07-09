-- S1: Rider Wallet & Earnings Ledger (issue #2)
-- Fast aggregate of a rider's earnings. Truth remains rider_earnings rows;
-- this table is credited atomically on order completion and debited by payouts.

CREATE TABLE IF NOT EXISTS rider_wallets (
  user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance         DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_earned    DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_withdrawn DECIMAL(10,2) NOT NULL DEFAULT 0,
  currency        VARCHAR(10)   NOT NULL DEFAULT 'GHS',
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Backfill wallets for any rider who already has earnings (safe re-run).
INSERT INTO rider_wallets (user_id, balance, total_earned)
SELECT rider_id, COALESCE(SUM(net),0), COALESCE(SUM(net),0)
FROM rider_earnings
GROUP BY rider_id
ON CONFLICT (user_id) DO NOTHING;
