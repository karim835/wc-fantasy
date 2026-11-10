-- Add UNIQUE constraint on national_teams.nationality
ALTER TABLE national_teams ADD CONSTRAINT national_teams_nationality_unique UNIQUE (nationality);
