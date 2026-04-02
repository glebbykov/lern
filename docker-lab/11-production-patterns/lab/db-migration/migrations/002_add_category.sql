-- 002: Add category column
ALTER TABLE notes ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'general';
