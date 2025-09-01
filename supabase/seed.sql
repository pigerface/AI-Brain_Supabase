-- Initial seed data for AI Brain Supabase
-- This file will be automatically loaded when running 'supabase db reset'

-- Example: Create initial roles and permissions
INSERT INTO auth.users (id, email, created_at) VALUES 
('00000000-0000-0000-0000-000000000001', 'admin@ai-brain.local', NOW())
ON CONFLICT (id) DO NOTHING;

-- Add your custom seed data below
-- Example tables, functions, triggers, etc.

