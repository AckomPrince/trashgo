-- S4: Rider Onboarding & Verification (issue #5)
-- Ghana Card + vehicle photo capture and an onboarding step marker.

ALTER TABLE rider_profiles
  ADD COLUMN IF NOT EXISTS ghana_card_number VARCHAR(30),
  ADD COLUMN IF NOT EXISTS ghana_card_url    VARCHAR(500),
  ADD COLUMN IF NOT EXISTS vehicle_photo_url VARCHAR(500),
  ADD COLUMN IF NOT EXISTS onboarding_step   VARCHAR(40) NOT NULL DEFAULT 'documents';
