-- Migration: Add user_id and user-scoped RLS
-- Run this in your Supabase SQL Editor if you already created the sessions table.

-- Add user_id column
ALTER TABLE sessions
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);

-- Drop old anonymous policies
DROP POLICY IF EXISTS "Allow inserts" ON sessions;
DROP POLICY IF EXISTS "Allow reads" ON sessions;

-- Users can only insert their own sessions
CREATE POLICY "Users insert own sessions"
ON sessions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can only read their own sessions
CREATE POLICY "Users read own sessions"
ON sessions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);
