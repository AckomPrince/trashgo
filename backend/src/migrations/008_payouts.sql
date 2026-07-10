-- P: Payments — Rider Payouts (issue #8)
-- Payout recipients (saved MoMo/bank destinations) + payout ledger.
-- Debits the S1 rider_wallets balance; settled/reversed via Paystack transfer webhook.

CREATE TABLE IF NOT EXISTS payout_recipients (
  id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type                     VARCHAR(20)  NOT NULL,          -- mobile_money | bank
  provider                 VARCHAR(40),                    -- MTN | Vodafone | AirtelTigo | bank name
  account_number           VARCHAR(50)  NOT NULL,
  account_name             VARCHAR(150),
  bank_code                VARCHAR(20),
  paystack_recipient_code  VARCHAR(100),
  is_default               BOOLEAN NOT NULL DEFAULT FALSE,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payout_recipients_rider ON payout_recipients(rider_id);

CREATE TABLE IF NOT EXISTS payouts (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id           UUID REFERENCES payout_recipients(id),
  amount                 DECIMAL(10,2) NOT NULL,
  currency               VARCHAR(10)  NOT NULL DEFAULT 'GHS',
  status                 VARCHAR(20)  NOT NULL DEFAULT 'pending', -- pending|processing|paid|failed|reversed
  reference              VARCHAR(100) UNIQUE NOT NULL,
  paystack_transfer_code VARCHAR(100),
  failure_reason         TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  settled_at             TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_payouts_rider    ON payouts(rider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_transfer ON payouts(paystack_transfer_code);
