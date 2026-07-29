-- CourseCraft -- allow quick controls to correct date-based attendance too.

alter table public.attendance_adjustments
  drop constraint if exists attendance_adjustments_attended_count_check,
  drop constraint if exists attendance_adjustments_missed_count_check;

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
declare
  v_present_count int;
  v_absent_count int;
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

  select count(*) filter (where status = 'present'),
         count(*) filter (where status = 'absent')
    into v_present_count, v_absent_count
  from public.attendance
  where space_id = p_space_id
    and subject_id = p_subject_id;

  insert into public.attendance_adjustments (
    space_id,
    subject_id,
    attended_count,
    missed_count
  )
  values (
    p_space_id,
    p_subject_id,
    case when p_status = 'present' then greatest(-v_present_count, p_delta) else 0 end,
    case when p_status = 'absent' then greatest(-v_absent_count, p_delta) else 0 end
  )
  on conflict (subject_id) do update set
    attended_count = greatest(
      -v_present_count,
      public.attendance_adjustments.attended_count +
        case when p_status = 'present' then p_delta else 0 end
    ),
    missed_count = greatest(
      -v_absent_count,
      public.attendance_adjustments.missed_count +
        case when p_status = 'absent' then p_delta else 0 end
    ),
    updated_at = now();
end;
$$;
