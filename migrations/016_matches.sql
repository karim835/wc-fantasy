-- WC 2026 fixtures persisted from football-data.org (competition "WC").
-- Populated by scripts/seed-gameweeks.js and refreshed by jobs/scoreSync.job.js.
-- Feeds the fixtures / live match-center screen and auto-gameweek generation.
CREATE TABLE IF NOT EXISTS matches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fd_match_id INTEGER UNIQUE,            -- football-data.org match id
  matchday    INTEGER,
  home_team   VARCHAR(100),
  away_team   VARCHAR(100),
  home_goals  INTEGER,
  away_goals  INTEGER,
  status      VARCHAR(20) DEFAULT 'SCHEDULED',  -- SCHEDULED | TIMED | IN_PLAY | PAUSED | FINISHED
  kickoff     TIMESTAMP,
  gameweek_id UUID REFERENCES gameweeks(id) ON DELETE SET NULL,
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matches_status   ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_matchday ON matches(matchday);
CREATE INDEX IF NOT EXISTS idx_matches_kickoff  ON matches(kickoff);
