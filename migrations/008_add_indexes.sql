-- Performance indexes on foreign keys
CREATE INDEX IF NOT EXISTS idx_teams_user_id ON teams(user_id);
CREATE INDEX IF NOT EXISTS idx_teams_league_id ON teams(league_id);
CREATE INDEX IF NOT EXISTS idx_battles_league_id ON battles(league_id);
CREATE INDEX IF NOT EXISTS idx_battles_home_team_id ON battles(home_team_id);
CREATE INDEX IF NOT EXISTS idx_battles_away_team_id ON battles(away_team_id);
CREATE INDEX IF NOT EXISTS idx_player_scores_player_id ON player_scores(player_id);
CREATE INDEX IF NOT EXISTS idx_player_scores_gameweek_id ON player_scores(gameweek_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_gameweek_id ON predictions(gameweek_id);
