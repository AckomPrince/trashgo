-- S2: Rider Ratings & Reliability (issue #3)
-- Customers rate riders; riders accrue an average rating and behavioural
-- counters used later by dispatch ranking (S3).

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS rider_rating SMALLINT CHECK (rider_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS rider_review TEXT;

ALTER TABLE rider_profiles
  ADD COLUMN IF NOT EXISTS rating_avg      DECIMAL(3,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count    INTEGER      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS accepted_count  INTEGER      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS completed_count INTEGER      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cancelled_count INTEGER      NOT NULL DEFAULT 0;
