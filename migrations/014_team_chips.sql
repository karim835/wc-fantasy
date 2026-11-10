-- Chips / boosts (WC trio): triple_captain, super_sub, shield. One use each per
-- tournament. A chip is "armed" for one upcoming gameweek, applied during score
-- recalculation, then moved into chips_used when that gameweek finishes.
ALTER TABLE teams ADD COLUMN IF NOT EXISTS active_chip      VARCHAR(20);
ALTER TABLE teams ADD COLUMN IF NOT EXISTS active_chip_gw   INTEGER;     -- gameweek NUMBER the chip applies to
ALTER TABLE teams ADD COLUMN IF NOT EXISTS boost_player_id  UUID;        -- super_sub target
ALTER TABLE teams ADD COLUMN IF NOT EXISTS chips_used       JSONB DEFAULT '[]';  -- [{chip, gameweek}]
