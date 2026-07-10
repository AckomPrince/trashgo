-- S5: Job Execution Polish (issue #6)
-- Proof-of-collection photo captured by the rider on completion.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS completion_photo_url VARCHAR(500);
