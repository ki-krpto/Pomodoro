-- Add long break settings to user_preferences

alter table user_preferences
  add column if not exists long_break_duration integer not null default 15,
  add column if not exists pomodoros_before_long_break integer not null default 4;
