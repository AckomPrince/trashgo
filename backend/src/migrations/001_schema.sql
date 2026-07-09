-- TrashGo Database Schema
-- Run this on a fresh PostgreSQL database

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- postgis is optional (geo queries use plain lat/lng DECIMAL columns, not geometry).
-- Skip gracefully when it isn't installed so a fresh dev machine can still migrate.
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS "postgis";
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'postgis extension not available — skipping (matching uses lat/lng columns)';
END$$;

-- ─────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────
CREATE TYPE user_role AS ENUM ('customer', 'rider', 'admin');
CREATE TYPE rider_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');

CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role            user_role NOT NULL DEFAULT 'customer',
  full_name       VARCHAR(150) NOT NULL,
  email           VARCHAR(255) NOT NULL,
  phone           VARCHAR(20) NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  profile_photo   VARCHAR(500),
  fcm_token       VARCHAR(500),           -- Firebase push token
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- FIX: email/phone uniqueness is scoped by role so a customer and rider can share
-- the same contact details, while still preventing duplicates within one role.
CREATE UNIQUE INDEX idx_users_email_role ON users (LOWER(email), role);
CREATE UNIQUE INDEX idx_users_phone_role ON users (phone, role);

-- Rider-specific profile
CREATE TABLE rider_profiles (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_type    VARCHAR(80),            -- truck, tricycle, van, etc.
  vehicle_plate   VARCHAR(30),
  id_document_url VARCHAR(500),
  license_url     VARCHAR(500),
  status          rider_status NOT NULL DEFAULT 'pending',
  admin_note      TEXT,
  is_online       BOOLEAN NOT NULL DEFAULT FALSE,
  current_lat     DECIMAL(10,8),
  current_lng     DECIMAL(11,8),
  last_seen_at    TIMESTAMPTZ,
  approved_at     TIMESTAMPTZ,
  approved_by     UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- ORDERS
-- ─────────────────────────────────────────
CREATE TYPE order_status AS ENUM (
  'requested',
  'accepted',
  'rider_en_route',
  'rider_arrived',
  'size_confirmed',       -- rider confirms waste size
  'price_approved',       -- customer approves price
  'payment_authorized',   -- paystack authorization hold
  'in_progress',
  'completed',
  'cancelled'
);

CREATE TYPE waste_type AS ENUM ('general', 'recyclable', 'organic', 'hazardous', 'bulky');
CREATE TYPE waste_size AS ENUM ('small', 'medium', 'large');

CREATE TABLE orders (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id         UUID NOT NULL REFERENCES users(id),
  rider_id            UUID REFERENCES users(id),

  -- Pickup location
  pickup_address      TEXT NOT NULL,
  pickup_lat          DECIMAL(10,8) NOT NULL,
  pickup_lng          DECIMAL(11,8) NOT NULL,

  -- Waste info
  waste_type          waste_type NOT NULL DEFAULT 'general',
  waste_size          waste_size,          -- set by rider on arrival
  waste_description   TEXT,
  waste_photo_url     VARCHAR(500),        -- optional photo by customer

  -- Status & timing
  status              order_status NOT NULL DEFAULT 'requested',
  requested_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at         TIMESTAMPTZ,
  arrived_at          TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,
  cancel_reason       TEXT,

  -- Pricing
  base_price          DECIMAL(10,2),       -- calculated after size confirmed
  final_price         DECIMAL(10,2),       -- same as base in MVP
  currency            VARCHAR(10) NOT NULL DEFAULT 'GHS',

  -- Payment
  payment_reference   VARCHAR(200),        -- Paystack reference
  payment_access_code VARCHAR(200),        -- Paystack authorization
  payment_status      VARCHAR(50) NOT NULL DEFAULT 'unpaid',  -- unpaid | authorized | paid | failed
  paid_at             TIMESTAMPTZ,

  -- Points
  points_awarded      INTEGER DEFAULT 0,
  points_finalized    BOOLEAN NOT NULL DEFAULT FALSE,

  -- Rating
  customer_rating     SMALLINT CHECK (customer_rating BETWEEN 1 AND 5),
  customer_review     TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- PRICING CONFIG (admin-managed)
-- ─────────────────────────────────────────
CREATE TABLE pricing_config (
  id          SERIAL PRIMARY KEY,
  waste_size  waste_size NOT NULL,
  waste_type  waste_type NOT NULL DEFAULT 'general',
  price       DECIMAL(10,2) NOT NULL,
  currency    VARCHAR(10) NOT NULL DEFAULT 'GHS',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(waste_size, waste_type)
);

-- Seed default pricing
INSERT INTO pricing_config (waste_size, waste_type, price) VALUES
  ('small',  'general',    5.00),
  ('medium', 'general',   10.00),
  ('large',  'general',   18.00),
  ('small',  'recyclable', 4.00),
  ('medium', 'recyclable', 8.00),
  ('large',  'recyclable',15.00),
  ('small',  'organic',    5.00),
  ('medium', 'organic',   10.00),
  ('large',  'organic',   18.00),
  ('small',  'hazardous', 12.00),
  ('medium', 'hazardous', 22.00),
  ('large',  'hazardous', 35.00),
  ('small',  'bulky',     15.00),
  ('medium', 'bulky',     25.00),
  ('large',  'bulky',     40.00);

-- ─────────────────────────────────────────
-- POINTS / REWARDS
-- ─────────────────────────────────────────
CREATE TYPE points_tx_type AS ENUM ('earned', 'redeemed', 'bonus', 'adjusted', 'expired');

CREATE TABLE points_transactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id),
  order_id      UUID REFERENCES orders(id),
  type          points_tx_type NOT NULL,
  amount        INTEGER NOT NULL,          -- positive = credit, negative = debit
  balance_after INTEGER NOT NULL,
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE points_wallets (
  user_id       UUID PRIMARY KEY REFERENCES users(id),
  balance       INTEGER NOT NULL DEFAULT 0,
  total_earned  INTEGER NOT NULL DEFAULT 0,
  total_redeemed INTEGER NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- REDEMPTIONS
-- ─────────────────────────────────────────
CREATE TYPE redemption_status AS ENUM ('pending', 'processing', 'paid', 'failed', 'rejected');

CREATE TABLE redemptions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id),
  points_redeemed   INTEGER NOT NULL,
  cash_value        DECIMAL(10,2) NOT NULL,
  currency          VARCHAR(10) NOT NULL DEFAULT 'GHS',
  payout_method     VARCHAR(50) NOT NULL,   -- mobile_money | bank_transfer
  payout_account    VARCHAR(200),           -- phone or account number
  payout_reference  VARCHAR(200),
  status            redemption_status NOT NULL DEFAULT 'pending',
  requested_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at      TIMESTAMPTZ,
  admin_note        TEXT
);

-- ─────────────────────────────────────────
-- RIDER EARNINGS
-- ─────────────────────────────────────────
CREATE TABLE rider_earnings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id    UUID NOT NULL REFERENCES users(id),
  order_id    UUID NOT NULL REFERENCES orders(id) UNIQUE,
  gross       DECIMAL(10,2) NOT NULL,
  commission  DECIMAL(10,2) NOT NULL DEFAULT 0,   -- platform fee
  net         DECIMAL(10,2) NOT NULL,
  currency    VARCHAR(10) NOT NULL DEFAULT 'GHS',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- NOTIFICATIONS LOG
-- ─────────────────────────────────────────
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id),
  title       VARCHAR(200) NOT NULL,
  body        TEXT NOT NULL,
  data        JSONB,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- DISPUTES
-- ─────────────────────────────────────────
CREATE TYPE dispute_status AS ENUM ('open', 'investigating', 'resolved', 'closed');

CREATE TABLE disputes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(id),
  raised_by   UUID NOT NULL REFERENCES users(id),
  reason      TEXT NOT NULL,
  status      dispute_status NOT NULL DEFAULT 'open',
  resolution  TEXT,
  resolved_by UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- REFRESH TOKENS
-- ─────────────────────────────────────────
-- Stored hashed; deleted on logout so stolen tokens can be revoked.
CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  VARCHAR(128) NOT NULL UNIQUE,   -- SHA-256 hex of the raw JWT
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at);

-- ─────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_rider      ON orders(rider_id);
CREATE INDEX idx_orders_status     ON orders(status);
CREATE INDEX idx_orders_created    ON orders(created_at DESC);
CREATE INDEX idx_rider_profiles_user ON rider_profiles(user_id);
CREATE INDEX idx_rider_online      ON rider_profiles(is_online) WHERE is_online = TRUE;
CREATE INDEX idx_points_user       ON points_transactions(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ─────────────────────────────────────────
-- UPDATED_AT TRIGGER
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated          BEFORE UPDATE ON users           FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rider_profiles_updated BEFORE UPDATE ON rider_profiles  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_orders_updated         BEFORE UPDATE ON orders          FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_disputes_updated       BEFORE UPDATE ON disputes        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
