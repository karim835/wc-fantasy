-- Extended user profile fields for WC Fantasy sign-up questionnaire
ALTER TABLE users ADD COLUMN IF NOT EXISTS country VARCHAR(60);
ALTER TABLE users ADD COLUMN IF NOT EXISTS favorite_nation VARCHAR(60);
ALTER TABLE users ADD COLUMN IF NOT EXISTS favorite_club VARCHAR(80);
ALTER TABLE users ADD COLUMN IF NOT EXISTS favorite_player VARCHAR(80);
-- date_of_birth and bio already added in migration 003
