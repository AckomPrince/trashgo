-- S6: Rider Engagement & Safety (issue #7)
-- Incentive definitions (progress computed at read time) + SOS event log.

CREATE TABLE IF NOT EXISTS rider_incentives (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id      UUID REFERENCES users(id) ON DELETE CASCADE,   -- NULL = global (all riders)
  type          VARCHAR(40)  NOT NULL,                          -- streak | volume | zone
  title         VARCHAR(150) NOT NULL,
  description   TEXT,
  target        INTEGER      NOT NULL DEFAULT 1,                -- e.g. complete N pickups
  reward_cash   DECIMAL(10,2) NOT NULL DEFAULT 0,
  reward_points INTEGER      NOT NULL DEFAULT 0,
  period        VARCHAR(20)  NOT NULL DEFAULT 'weekly',         -- daily | weekly | monthly
  status        VARCHAR(20)  NOT NULL DEFAULT 'active',         -- active | expired
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rider_sos_events (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id    UUID REFERENCES orders(id),
  lat         DECIMAL(10,8),
  lng         DECIMAL(11,8),
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sos_created ON rider_sos_events(created_at DESC);

-- Seed a couple of global incentives (idempotent-ish: only when table is empty).
INSERT INTO rider_incentives (rider_id, type, title, description, target, reward_cash, reward_points, period)
SELECT NULL, 'volume', 'Weekly Hustler', 'Complete 10 pickups this week', 10, 20.00, 0, 'weekly'
WHERE NOT EXISTS (SELECT 1 FROM rider_incentives WHERE title='Weekly Hustler');

INSERT INTO rider_incentives (rider_id, type, title, description, target, reward_cash, reward_points, period)
SELECT NULL, 'streak', 'Daily Triple', 'Complete 3 pickups today', 3, 0, 100, 'daily'
WHERE NOT EXISTS (SELECT 1 FROM rider_incentives WHERE title='Daily Triple');
