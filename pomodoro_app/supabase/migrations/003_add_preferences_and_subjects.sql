-- User preferences (presets, break duration) synced per user

create table user_preferences (
  user_id uuid primary key references auth.users(id),
  presets integer[] not null default array[25, 45, 60],
  break_duration integer not null default 5,
  updated_at timestamptz default now() not null
);

alter table user_preferences enable row level security;

create policy "Users manage own preferences"
on user_preferences
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Subjects synced per user

create table subjects (
  id text primary key,
  user_id uuid references auth.users(id) not null,
  name text not null,
  color integer not null,
  created_at timestamptz default now() not null
);

alter table subjects enable row level security;

create policy "Users manage own subjects"
on subjects
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
