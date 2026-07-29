-- CourseCraft -- manual attendance counters for quick corrections.

create table if not exists public.attendance_adjustments (
  space_id       uuid not null references public.spaces(id) on delete cascade,
  subject_id     uuid primary key references public.subjects(id) on delete cascade,
  attended_count int not null default 0 check (attended_count >= 0),
  missed_count   int not null default 0 check (missed_count >= 0),
  updated_at     timestamptz not null default now()
);

alter table public.attendance_adjustments enable row level security;

create policy attendance_adjustments_select on public.attendance_adjustments
  for select using (public.is_space_member(space_id));
create policy attendance_adjustments_write on public.attendance_adjustments
  for all using (public.is_space_student(space_id))
  with check (public.is_space_student(space_id));

alter publication supabase_realtime add table public.attendance_adjustments;

create or replace function public.adjust_attendance(
  p_space_id uuid,
  p_subject_id uuid,
  p_status text,
  p_delta int
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.is_space_student(p_space_id) then
    raise exception 'not_allowed';
  end if;
  if p_status not in ('present', 'absent') then
    raise exception 'invalid_status';
  end if;
  if p_delta not in (-1, 1) then
    raise exception 'invalid_delta';
  end if;

  insert into public.attendance_adjustments (space_id, subject_id, attended_count, missed_count)
  values (
    p_space_id,
    p_subject_id,
    case when p_status = 'present' and p_delta = 1 then 1 else 0 end,
    case when p_status = 'absent' and p_delta = 1 then 1 else 0 end
  )
  on conflict (subject_id) do update set
    attended_count = greatest(0, public.attendance_adjustments.attended_count +
      case when p_status = 'present' then p_delta else 0 end),
    missed_count = greatest(0, public.attendance_adjustments.missed_count +
      case when p_status = 'absent' then p_delta else 0 end),
    updated_at = now();
end;
$$;
