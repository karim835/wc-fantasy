-- Ensure every league has an invite code (previously only private leagues got one)
UPDATE leagues
SET invite_code = UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', '') FROM 1 FOR 8))
WHERE invite_code IS NULL;

-- Make invite_code NOT NULL going forward (optional hardening)
-- ALTER TABLE leagues ALTER COLUMN invite_code SET NOT NULL;
