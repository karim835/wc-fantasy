-- Bio columns for full player profiles (age / height / weight).
-- Populated by scripts/backfill-player-data.js (TheSportsDB). photo_url already
-- exists from migration 002.
ALTER TABLE players ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE players ADD COLUMN IF NOT EXISTS height_cm INT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS weight_kg INT;
