-- CourseCraft -- configurable per-subject attendance targets.
alter table public.subjects
  add column if not exists attendance_target numeric(5,2) not null default 75
  check (attendance_target > 0 and attendance_target <= 100);
