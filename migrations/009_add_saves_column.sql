-- Add saves column for goalkeeper stats
ALTER TABLE player_scores ADD COLUMN IF NOT EXISTS saves INTEGER DEFAULT 0;
