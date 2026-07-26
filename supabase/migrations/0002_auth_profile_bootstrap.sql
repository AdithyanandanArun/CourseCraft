-- ============================================================================
-- CourseCraft -- Phase 1 auth/profile bootstrap
-- Every signed-up account receives a profile. Student accounts also receive a
-- solo space immediately, so academic features never depend on advisor pairing.
-- ============================================================================

create or replace function public.create_profile_for_user(
  p_user_id uuid,
  p_role text,
  p_display_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(trim(coalesce(p_role, 'student')));
  v_display_name text := nullif(trim(p_display_name), '');
  v_space_id uuid;
  v_profile public.profiles%rowtype;
begin
  if p_user_id is null then
    raise exception 'missing_user';
  end if;

  if v_role not in ('student', 'advisor') then
    raise exception 'invalid_role';
  end if;

  select * into v_profile from public.profiles where id = p_user_id;
  if found then
    return v_profile;
  end if;

  if v_role = 'student' then
    insert into public.spaces (student_id)
    values (p_user_id)
    on conflict (student_id) do update set student_id = excluded.student_id
    returning id into v_space_id;
  end if;

  insert into public.profiles (id, role, display_name, space_id)
  values (p_user_id, v_role, v_display_name, v_space_id)
  returning * into v_profile;

  return v_profile;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.create_profile_for_user(
    new.id,
    new.raw_user_meta_data ->> 'role',
    new.raw_user_meta_data ->> 'display_name'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.ensure_my_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user auth.users%rowtype;
begin
  select * into v_user from auth.users where id = auth.uid();
  if not found then
    raise exception 'unauthenticated';
  end if;

  return public.create_profile_for_user(
    v_user.id,
    v_user.raw_user_meta_data ->> 'role',
    v_user.raw_user_meta_data ->> 'display_name'
  );
end;
$$;

revoke all on function public.create_profile_for_user(uuid, text, text) from public;
revoke all on function public.handle_new_user() from public;
grant execute on function public.ensure_my_profile() to authenticated;
