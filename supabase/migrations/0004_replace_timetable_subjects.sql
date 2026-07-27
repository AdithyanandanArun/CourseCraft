-- CourseCraft -- replace a semester timetable and its subjects as one action.
-- Removing a subject cascades to assessments and attendance; linked events/tasks retain their row.

create or replace function public.clear_timetable_and_subjects(
  p_space_id uuid,
  p_semester_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_space_student(p_space_id) then raise exception 'not_space_student'; end if;
  if not exists (select 1 from public.semesters where id = p_semester_id and space_id = p_space_id) then
    raise exception 'invalid_semester';
  end if;
  delete from public.timetable_slots where space_id = p_space_id;
  delete from public.subjects where space_id = p_space_id and semester_id = p_semester_id;
end;
$$;

grant execute on function public.clear_timetable_and_subjects(uuid, uuid) to authenticated;

create or replace function public.import_timetable_json(
  p_space_id uuid,
  p_semester_id uuid,
  p_timetable jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject jsonb; v_schedule jsonb; v_class jsonb; v_subject_id uuid;
  v_subject_name text; v_day int; v_created_subjects int := 0; v_created_slots int := 0;
begin
  if not public.is_space_student(p_space_id) then raise exception 'not_space_student'; end if;
  if not exists (select 1 from public.semesters where id = p_semester_id and space_id = p_space_id) then raise exception 'invalid_semester'; end if;
  if jsonb_typeof(p_timetable->'subjects') <> 'array' then raise exception 'invalid_timetable: subjects must be an array'; end if;

  -- A timetable import is a replacement, never an additive merge.
  delete from public.timetable_slots where space_id = p_space_id;
  delete from public.subjects where space_id = p_space_id and semester_id = p_semester_id;

  for v_subject in select value from jsonb_array_elements(p_timetable->'subjects') loop
    v_subject_name := nullif(trim(v_subject->>'name'), '');
    if v_subject_name is null then raise exception 'invalid_timetable: subject name is required'; end if;
    insert into public.subjects (space_id, semester_id, name, credits)
    values (p_space_id, p_semester_id, v_subject_name, 3)
    returning id into v_subject_id;
    v_created_subjects := v_created_subjects + 1;
    for v_schedule in select value from jsonb_array_elements(coalesce(v_subject->'schedules', '[]'::jsonb)) loop
      v_day := case lower(trim(v_schedule->>'day')) when 'monday' then 1 when 'tuesday' then 2 when 'wednesday' then 3 when 'thursday' then 4 when 'friday' then 5 when 'saturday' then 6 when 'sunday' then 7 else null end;
      if v_day is null then raise exception 'invalid_timetable: unknown day'; end if;
      for v_class in select value from jsonb_array_elements(coalesce(v_schedule->'classTimes', '[]'::jsonb)) loop
        if nullif(trim(v_class->>'startTime'), '') is null or nullif(trim(v_class->>'endTime'), '') is null then raise exception 'invalid_timetable: class times are required'; end if;
        insert into public.timetable_slots (space_id, day_of_week, start_time, end_time, subject_id, room)
        values (p_space_id, v_day, to_timestamp(trim(v_class->>'startTime'), 'HH12:MI AM')::time, to_timestamp(trim(v_class->>'endTime'), 'HH12:MI AM')::time, v_subject_id, nullif(trim(v_class->>'roomNumber'), ''));
        v_created_slots := v_created_slots + 1;
      end loop;
    end loop;
  end loop;
  return jsonb_build_object('subjectsCreated', v_created_subjects, 'slotsCreated', v_created_slots);
end;
$$;
