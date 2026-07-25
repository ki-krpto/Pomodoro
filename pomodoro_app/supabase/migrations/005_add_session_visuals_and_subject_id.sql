-- Add subject_id (FK-style text ref) and visual placement columns to sessions.
-- The old `subject` text column is kept for backward-compatible reads.

alter table sessions add column if not exists subject_id text;
alter table sessions add column if not exists dx double precision not null default 0;
alter table sessions add column if not exists dy double precision not null default 0;
alter table sessions add column if not exists rotation_deg double precision not null default 0;
alter table sessions add column if not exists color_index integer not null default 0;
