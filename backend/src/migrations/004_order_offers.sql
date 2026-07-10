-- S3: Smart Dispatch & Job Feed (issue #4)
-- Persisted offers let riders decline, let offers expire, and let accept close
-- sibling offers. A decline counter feeds the reliability picture.

DO $$ BEGIN
  CREATE TYPE offer_status AS ENUM ('offered', 'accepted', 'declined', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS order_offers (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  rider_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      offer_status NOT NULL DEFAULT 'offered',
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, rider_id)
);
CREATE INDEX IF NOT EXISTS idx_order_offers_rider ON order_offers(rider_id, status);
CREATE INDEX IF NOT EXISTS idx_order_offers_order ON order_offers(order_id, status);

ALTER TABLE rider_profiles
  ADD COLUMN IF NOT EXISTS declined_count INTEGER NOT NULL DEFAULT 0;
