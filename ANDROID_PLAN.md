# CourseCraft Android Delivery Guide

The workspace-level roadmap is `../Plan.md`. This document keeps Android-specific implementation
notes close to the Flutter application.

> Companion to `Idea.md`. This is the **build order**: what to implement first, in what phases,
> and how to verify each. Each phase is an independently demoable vertical slice. Build them in
> order — later phases assume the earlier backbone exists.

---

## Architecture at a glance

**Stack:** Flutter (Android) · Supabase (Auth + Postgres + Storage + Realtime) · Riverpod ·
go_router · pure-Dart grading engine.

| Concern | Choice | Why |
|---|---|---|
| UI | Flutter Android, role-aware | Native Android student and advisor experience |
| State | **Riverpod 3** (+ generator, lint) | Supabase streams → `AsyncValue`, auto-recompute SGPA |
| Routing | **go_router** + auth/role guards | Declarative, deep-link ready |
| Models | **freezed** + json_serializable | Immutable, codegen serialization |
| Backend | **Supabase** `supabase_flutter` | Relational data + RLS fits the student/advisor model |
| Notifications | `flutter_local_notifications` + `timezone` + `permission_handler` | Local reminders (v1) |
| Charts | `fl_chart` + custom `CustomPainter` gauge | No paid-license dependency |
| Images | `image_picker` + Supabase Storage | Shared so advisor can see her work |
| Forms/dates | `flutter_form_builder`, `intl`, `table_calendar` | Fast multi-field entry, calendar UI |

**Backend setup:** one Supabase project · Postgres schema via SQL migrations · RLS on every table ·
one Storage bucket `attachments` scoped per space · pairing via a `SECURITY DEFINER` RPC. No Edge
Functions in v1.

**v1 deliberately excludes:** advisor remote push, milestones/rewards, widgets, and iOS release.
Advisor notifications surface as in-app messages for now.

---

## Data model (Postgres)

Anchor table is **`spaces`** (one per student; `advisor_id` set on pairing). Every domain table
carries `space_id`; RLS is expressed once via helpers `is_space_member(space_id)` /
`is_space_student(space_id)`.

| Table | Key columns |
|---|---|
| `profiles` | `id`=auth.uid, `role`, `display_name`, `space_id` |
| `spaces` | `id`, `student_id`, `advisor_id?`, `target_sgpa` (default 9.5) |
| `pairing_codes` | `code` PK, `space_id`, `student_id`, `expires_at`, `consumed`, `advisor_id?` |
| `semesters` | `id`, `space_id`, `name`, `idx`, `status`, `sgpa`, `total_credits` |
| `subjects` | `id`, `semester_id`, `name`, `code`, `credits`, `target_grade` |
| `assessments` | `id`, `subject_id`, `title`, `type`, `weight_pct`, `max_marks`, `obtained_marks?`, `date` |
| `timetable_slots` | `id`, `space_id`, `day_of_week`, `start_time`, `end_time`, `subject_id`, `room`, `faculty` |
| `timetable_exceptions` | `id`, `space_id`, `date`, `slot_id?`, `type` (cancel/extra/reschedule/holiday) |
| `attendance` | `id`, `space_id`, `subject_id`, `date`, `status` (present/absent/cancelled) |
| `events` | `id`, `space_id`, `type`, `subject_id?`, `title`, `start_at`, `end_at?`, `max_marks?`, `notify_before` |
| `tasks` | `id`, `space_id`, `title`, `due_at`, `done`, `created_by`, `priority`, `recurrence?`, `linked_subject_id?`, `linked_event_id?` |
| `goals` | `id`, `space_id`, `type`, `target`, `subject_id?` |
| `notes` | `id`, `space_id`, `body`, `created_by`, `created_at` |
| `habits` / `habit_checkins` | `habits(id, space_id, name)` · `habit_checkins(habit_id, date)` |
| `messages` | `id`, `space_id`, `from_role`, `title`, `body`, `created_at`, `read` (advisor encouragement, in-app) |
| `attachments` | `id`, `space_id`, `bucket_path`, `caption`, `linked_type`, `linked_id`, `uploaded_by`, `created_at` |

**RLS:** `SELECT` if `is_space_member(space_id)`. Writes to academic tables
(semesters/subjects/assessments/timetable*/attendance/events/habits) require `is_space_student`.
Coaching tables (tasks/goals/notes/messages/attachments) allow both members. `pairing_codes`:
student creates own; advisor claims only via the RPC.

**Pairing RPC** `claim_pairing_code(code)` (SECURITY DEFINER, atomic): validate unconsumed +
unexpired → set `spaces.advisor_id = auth.uid()`, `profiles.space_id`, mark `consumed`.

**Grading engine** (`lib/core/grading/`, pure Dart, unit-tested, no Supabase): configurable grade
bands (O=10, A+=9, A=8, B+=7, B=6, C=5, …), credit-weighted SGPA, per-subject predicted grade from
weighted assessments, projected SGPA, and the 9.5 **back-calculator** (min marks needed in
remaining assessments; flag mathematically unreachable subjects).

---

## Phases

### Phase 0 — Foundations & setup *(unblocks everything)*
- Install Flutter toolchain; `flutter create` (Android).
- Create Supabase project; wire `supabase_flutter`; env config for keys.
- Add packages; set up Riverpod + go_router + freezed + clean-minimal theme tokens.
- App shell: `ProviderScope`, router with auth guard, splash.
- SQL migration `0001_init.sql`: all tables + helper functions + RLS + `attachments` bucket.
- **Verify:** app boots, connects to Supabase, an anonymous read is denied by RLS.

### Phase 1 — Auth, roles & pairing *(two-person backbone)*
- Email/password sign-up + login; session persistence.
- First-launch role selection (student/advisor); create `profiles`; student also gets a `spaces` row.
- Student generates a pairing code; advisor enters it → `claim_pairing_code` links the accounts.
- Role-aware navigation shell (student tabs vs advisor tabs).
- **Verify:** two accounts on two devices link; advisor sees the empty student space; an unlinked third account is blocked.

### Phase 2 — Academics core + SGPA engine *(the heart of 9.5)*
- Semesters CRUD (current + history); subjects CRUD (credits + per-subject assessment weights).
- Pure-Dart grading engine + unit tests.
- Marks entry (assessments) per subject; live predicted grade + projected SGPA.
- **Verify:** enter subjects + marks → projected SGPA matches a hand calculation; unit tests green.

### Phase 3 — The 9.5 dashboard & predictor *(data → motivation)*
- 9.5 target radial gauge; projected-vs-target; per-subject progress bars; on-track / behind status.
- "What you need" panel: min marks per remaining assessment to still hit 9.5; flag unreachable.
- CGPA trend chart across semesters.
- **Verify:** changing a mark moves the gauge and the required-marks numbers correctly.

### Phase 4 — Timetable & attendance
- Weekly grid (days × periods): subject, time, room, faculty; exceptions (cancel/extra/reschedule/holiday).
- Per-class attendance marking driven off the timetable.
- 75% logic per subject: "classes you can still skip" / "must attend"; nudge thresholds; holidays excluded.
- **Verify:** marking absences updates % and the skip/attend counter; holidays don't penalize.

### Phase 5 — Calendar & events
- Events: exams/quizzes/mid-sem/end-sem (optional max-marks feed the predictor), assignment deadlines, holidays/college events.
- Unified month/agenda calendar; holidays propagate to timetable/attendance.
- **Verify:** events appear on the calendar; an exam with marks flows into the predictor.

### Phase 6 — Tasks
- Advisor-assigned + her own + recurring + linked-to-subject/event; due dates, priority, done state.
- Completion visible to advisor.
- **Verify:** advisor creates a task → appears on her device via Realtime; she completes it → advisor sees it.

### Phase 7 — Advisor coaching tools
- Advisor read-only mirror of her dashboard/academics/attendance.
- Set goals/targets (9.5, per-subject target grades); notes/feedback she can read.
- Encouragement messages surfaced in-app when she opens the app.
- **Verify:** advisor sets a target + note + message; all three render on her side.

### Phase 8 — Notifications (local, v1)
- Class/test reminders, task-due reminders, daily summary, attendance nudges.
- Permission handling (Android 13+ POST_NOTIFICATIONS, 12+ exact-alarm; iOS prompt); inexact fallback.
- In-app surfacing of advisor messages (no remote push in v1).
- **Verify:** a class scheduled soon fires a local notification; the daily summary appears.

### Phase 9 — Images via Supabase Storage
- `image_picker` → upload to `attachments` bucket (RLS per space, downscaled); attach to assessment/note/event.
- Both student and advisor can view; local cache via `path_provider`.
- **Verify:** she uploads a marksheet photo → advisor sees the actual image on his device.

### Phase 10 — Motivation polish, hardening & distribution
- Streaks & habits; clean-minimal theming pass; empty/error/offline states; Realtime + offline reconciliation.
- Android: `flutter build apk` + sideload to your phone.
- Seed her real next-semester subjects/credits/timetable.
- **Verify:** clean install on both phones; full loop (timetable → attendance → marks → 9.5 dashboard → advisor task) works end to end.

---

## Deferred to v2
Advisor **remote push** (paid Apple Developer + APNs key, plus FCM/OneSignal or a Supabase Edge
Function), milestones/rewards, home-screen widgets, App Store release, richer analytics.

---

## Critical files (created across phases)
- `pubspec.yaml` — the package set above
- `supabase/migrations/0001_init.sql` — tables, `is_space_member`/`is_space_student`, RLS, `claim_pairing_code`, bucket
- `lib/core/grading/sgpa_engine.dart` (+ `test/grading/sgpa_engine_test.dart`)
- `lib/core/services/supabase_service.dart`, `lib/core/services/notification_service.dart`
- `lib/core/router/app_router.dart`
- `lib/features/{auth,pairing,academics,dashboard,timetable,attendance,events,tasks,notes,habits,advisor}/…`

## End-to-end verification (v1 done)
1. Two clean installs; student signs up, generates code; advisor signs up, claims it → linked.
2. Student adds semester + subjects (credits + weights) + a few marks → 9.5 dashboard shows projected SGPA and required marks.
3. Student builds the weekly timetable, marks attendance → 75% counter correct.
4. Advisor assigns a task + sets a target + sends an encouragement message → all appear on the student device (Realtime).
5. Local class reminder fires on the student phone; daily summary appears.
6. Student uploads a photo → advisor views the actual image.
7. RLS check: a third unrelated account cannot read either space.
