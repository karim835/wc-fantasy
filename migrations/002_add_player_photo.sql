-- Add photo_url column to players table
ALTER TABLE players ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);
