-- National teams and fixtures for World Cup 2026
CREATE TABLE IF NOT EXISTS national_teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  nationality VARCHAR(50) NOT NULL,
  flag_url VARCHAR(500),
  group_name VARCHAR(10),
  fifa_ranking INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS national_fixtures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  home_team_id UUID REFERENCES national_teams(id) ON DELETE CASCADE,
  away_team_id UUID REFERENCES national_teams(id) ON DELETE CASCADE,
  gameweek_id UUID REFERENCES gameweeks(id) ON DELETE SET NULL,
  match_date TIMESTAMP,
  home_score INTEGER,
  away_score INTEGER,
  status VARCHAR(20) DEFAULT 'scheduled',
  stage VARCHAR(50) DEFAULT 'group',
  created_at TIMESTAMP DEFAULT NOW()
);
