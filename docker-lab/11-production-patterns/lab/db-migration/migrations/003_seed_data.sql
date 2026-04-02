-- 003: Seed initial data
INSERT INTO notes (text, category)
SELECT 'Welcome to the app', 'system'
WHERE NOT EXISTS (SELECT 1 FROM notes WHERE category = 'system');
