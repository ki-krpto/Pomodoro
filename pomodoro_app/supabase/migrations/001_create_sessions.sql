-- For fresh installs: run this first, then run 002_add_user_id_rls.sql

create table sessions (
  id bigint primary key generated always as identity,
  created_at timestamptz default now() not null,
  user_id uuid references auth.users(id),
  subject text,
  duration_minutes integer not null,
  completed boolean not null default true
);

alter table sessions enable row level security;

create policy "Users insert own sessions"
on sessions
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users read own sessions"
on sessions
for select
to authenticated
using (auth.uid() = user_id);
