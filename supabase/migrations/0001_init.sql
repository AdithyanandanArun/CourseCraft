-- ============================================================================
-- CourseCraft — initial schema (Phase 0)
-- Backend: Supabase (Postgres + RLS + Storage)
-- Model: one "space" per student; the linked advisor_id grants full read.
-- Apply via: Supabase Dashboard → SQL Editor (paste & run), or `supabase db push`.
-- ============================================================================

-- gen_random_uuid() lives in pgcrypto (preinstalled on Supabase, but be safe).
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Core: profiles + spaces + pairing
-- ----------------------------------------------------------------------------

create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  role         text not null check (role in ('student','advisor')),
  display_name text,
  space_id     uuid,                      -- student: own space; advisor: linked student's space
  created_at   timestamptz not null default now()
);

create table if not exists public.spaces (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null unique references auth.users(id) on delete cascade,
  advisor_id  uuid references auth.users(id) on delete set null,
  target_sgpa numeric(3,2) not null default 9.50,
  created_at  timestamptz not null default now()
);

-- profiles.space_id → spaces.id (added after spaces exists)
do $$ begin
  alter table public.profiles
    add constraint profiles_space_fk foreign key (space_id) references public.spaces(id) on delete set null;
exception when duplicate_object then null; end $$;

create table if not exists public.pairing_codes (
  code       text primary key,                       -- short, e.g. 6 chars, student-generated
  space_id   uuid not null references public.spaces(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  advisor_id uuid references auth.users(id),
  consumed   boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Academics
-- ----------------------------------------------------------------------------

create table if not exists public.semesters (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,
  name          text not null,
  idx           int  not null default 0,
  status        text not null default 'active' check (status in ('active','completed','upcoming')),
  sgpa          numeric(4,2),               -- denormalized, recomputed on write
  total_credits numeric(5,1),
  created_at    timestamptz not null default now()
);

create table if not exists public.subjects (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,  -- denormalized for RLS
  semester_id  uuid not null references public.semesters(id) on delete cascade,
  name         text not null,
  code         text,
  credits      numeric(4,1) not null default 3,
  target_grade text,
  created_at   timestamptz not null default now()
);

-- Each row is one assessment slot (quiz/assignment/mid/end). obtained_marks NULL = not taken yet.
create table if not exists public.assessments (
  id             uuid primary key default gen_random_uuid(),
  space_id       uuid not null references public.spaces(id) on delete cascade,
  subject_id     uuid not null references public.subjects(id) on delete cascade,
  title          text not null,
  type           text not null default 'other'
                   check (type in ('quiz','assignment','mid','end','lab','project','other')),
  weight_pct     numeric(5,2) not null default 0,    -- contribution to final grade
  max_marks      numeric(7,2) not null default 100,
  obtained_marks numeric(7,2),                       -- NULL until taken
  date           date,
  created_at     timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Timetable + attendance
-- ----------------------------------------------------------------------------

create table if not exists public.timetable_slots (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid not null references public.spaces(id) on delete cascade,
  day_of_week int  not null check (day_of_week between 1 and 7),   -- 1=Mon
  start_time  time not null,
  end_time    time not null,
  subject_id  uuid references public.subjects(id) on delete set null,
  room        text,
  faculty     text,
  created_at  timestamptz not null default now()
);

create table if not exists public.timetable_exceptions (
  id        uuid primary key default gen_random_uuid(),
  space_id  uuid not null references public.spaces(id) on delete cascade,
  date      date not null,
  slot_id   uuid references public.timetable_slots(id) on delete cascade,
  type      text not null check (type in ('cancel','extra','reschedule','holiday')),
  note      text,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  date       date not null,
  status     text not null check (status in ('present','absent','cancelled')),
  created_at timestamptz not null default now(),
  unique (subject_id, date)
);

-- ----------------------------------------------------------------------------
-- Calendar events
-- ----------------------------------------------------------------------------

create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,
  type         text not null check (type in ('exam','quiz','assignment','holiday','college','personal')),
  subject_id   uuid references public.subjects(id) on delete set null,
  title        text not null,
  start_at     timestamptz not null,
  end_at       timestamptz,
  max_marks    numeric(7,2),
  notify_before int,                       -- minutes before to remind
  created_at   timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Coaching: tasks / goals / notes / habits / messages
-- ----------------------------------------------------------------------------

create table if not exists public.tasks (
  id               uuid primary key default gen_random_uuid(),
  space_id         uuid not null references public.spaces(id) on delete cascade,
  title            text not null,
  due_at           timestamptz,
  done             boolean not null default false,
  created_by       uuid not null references auth.users(id),
  created_by_role  text not null check (created_by_role in ('student','advisor')),
  priority         text not null default 'normal' check (priority in ('low','normal','high')),
  recurrence       text,                   -- null=one-off; e.g. 'daily','weekly'
  linked_subject_id uuid references public.subjects(id) on delete set null,
  linked_event_id   uuid references public.events(id)   on delete set null,
  created_at       timestamptz not null default now()
);

create table if not exists public.goals (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces(id) on delete cascade,
  type       text not null,               -- 'sgpa','subject_grade','study'
  target     text not null,
  subject_id uuid references public.subjects(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.notes (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces(id) on delete cascade,
  body       text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.habits (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.habit_checkins (
  habit_id uuid not null references public.habits(id) on delete cascade,
  space_id uuid not null references public.spaces(id) on delete cascade,
  date     date not null,
  primary key (habit_id, date)
);

create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references public.spaces(id) on delete cascade,
  from_role  text not null check (from_role in ('student','advisor')),
  title      text,
  body       text not null,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.attachments (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid not null references public.spaces(id) on delete cascade,
  bucket_path text not null,              -- storage object path: {space_id}/{uuid}.jpg
  caption     text,
  linked_type text,                       -- 'assessment'|'note'|'event'|'subject'|null
  linked_id   uuid,
  uploaded_by uuid not null references auth.users(id),
  created_at  timestamptz not null default now()
);

-- Helpful indexes for space-scoped queries
create index if not exists idx_subjects_space    on public.subjects(space_id);
create index if not exists idx_assessments_subj  on public.assessments(subject_id);
create index if not exists idx_attendance_space  on public.attendance(space_id, subject_id);
create index if not exists idx_events_space       on public.events(space_id, start_at);
create index if not exists idx_tasks_space        on public.tasks(space_id, done);

-- ----------------------------------------------------------------------------
-- RLS helper functions (SECURITY DEFINER → can read spaces regardless of caller)
-- ----------------------------------------------------------------------------

create or replace function public.is_space_member(p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.spaces s
    where s.id = p_space and (s.student_id = auth.uid() or s.advisor_id = auth.uid())
  );
$$;

create or replace function public.is_space_student(p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.spaces s
    where s.id = p_space and s.student_id = auth.uid()
  );
$$;

-- ----------------------------------------------------------------------------
-- Enable RLS on every table
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','spaces','pairing_codes','semesters','subjects','assessments',
    'timetable_slots','timetable_exceptions','attendance','events',
    'tasks','goals','notes','habits','habit_checkins','messages','attachments'
  ] loop
    execute format('alter table public.%I enable row level security;', t);
  end loop;
end $$;

-- profiles: read self + your space partner; write self only
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or id in (select student_id from public.spaces where advisor_id = auth.uid())
  or id in (select advisor_id from public.spaces where student_id = auth.uid())
);
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
create policy profiles_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- spaces: members read; student creates & updates own (advisor link is set via RPC only)
create policy spaces_select on public.spaces for select using (
  student_id = auth.uid() or advisor_id = auth.uid()
);
create policy spaces_insert on public.spaces for insert with check (student_id = auth.uid());
create policy spaces_update on public.spaces for update using (student_id = auth.uid()) with check (student_id = auth.uid());

-- pairing_codes: only the owning student can see/create them; claiming happens via RPC
create policy codes_select on public.pairing_codes for select using (student_id = auth.uid());
create policy codes_insert on public.pairing_codes for insert with check (student_id = auth.uid());

-- Generic space-scoped policies. Academic tables = student-write; coaching = any member-write.
do $$
declare
  student_write text[] := array['semesters','subjects','assessments','timetable_slots',
                                 'timetable_exceptions','attendance','events','habits','habit_checkins'];
  member_write  text[] := array['tasks','goals','notes','messages','attachments'];
  t text;
begin
  foreach t in array student_write loop
    execute format('create policy %1$s_select on public.%1$s for select using (public.is_space_member(space_id));', t);
    execute format('create policy %1$s_write  on public.%1$s for all    using (public.is_space_student(space_id)) with check (public.is_space_student(space_id));', t);
  end loop;
  foreach t in array member_write loop
    execute format('create policy %1$s_select on public.%1$s for select using (public.is_space_member(space_id));', t);
    execute format('create policy %1$s_write  on public.%1$s for all    using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));', t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Pairing RPC: advisor claims a student's code → link the two accounts atomically
-- ----------------------------------------------------------------------------
create or replace function public.claim_pairing_code(p_code text)
returns public.spaces language plpgsql security definer set search_path = public as $$
declare
  v_code public.pairing_codes%rowtype;
  v_space public.spaces%rowtype;
begin
  select * into v_code from public.pairing_codes
    where code = p_code for update;

  if not found then raise exception 'invalid_code'; end if;
  if v_code.consumed then raise exception 'code_already_used'; end if;
  if v_code.expires_at < now() then raise exception 'code_expired'; end if;
  if v_code.student_id = auth.uid() then raise exception 'cannot_pair_with_self'; end if;

  update public.spaces
     set advisor_id = auth.uid()
   where id = v_code.space_id and advisor_id is null
   returning * into v_space;

  if not found then raise exception 'space_already_paired'; end if;

  update public.profiles set space_id = v_code.space_id where id = auth.uid();
  update public.pairing_codes set consumed = true, advisor_id = auth.uid() where code = p_code;

  return v_space;
end $$;

grant execute on function public.claim_pairing_code(text) to authenticated;

-- ----------------------------------------------------------------------------
-- Storage: private 'attachments' bucket, path convention {space_id}/<file>
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('attachments','attachments', false)
on conflict (id) do nothing;

-- Object access scoped by the first path segment = space_id, gated by membership.
create policy attachments_select on storage.objects for select using (
  bucket_id = 'attachments'
  and public.is_space_member( ((storage.foldername(name))[1])::uuid )
);
create policy attachments_insert on storage.objects for insert with check (
  bucket_id = 'attachments'
  and public.is_space_member( ((storage.foldername(name))[1])::uuid )
);
create policy attachments_delete on storage.objects for delete using (
  bucket_id = 'attachments'
  and public.is_space_member( ((storage.foldername(name))[1])::uuid )
);

-- ============================================================================
-- End 0001_init.sql
-- ============================================================================
