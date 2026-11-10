-- Separate XP from fantasy points to avoid polluting league rankings
ALTER TABLE users ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;
