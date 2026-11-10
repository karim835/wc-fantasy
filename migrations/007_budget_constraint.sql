-- Add CHECK constraint to ensure budget never goes negative
ALTER TABLE teams ADD CONSTRAINT teams_budget_non_negative CHECK (budget >= 0);
