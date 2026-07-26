# Idea.md — CourseCraft

> A personal, two-person academic coaching app. One student (her), one advisor (you),
> built to drive a single concrete goal: **a 9.5 SGPA next semester.**

---

## 1. The one-line pitch

A mobile app where she tracks everything academic — timetable, attendance, tests, quizzes,
exams, assignments, grades, and study tasks — while you, as her advisor, see her progress,
assign tasks, set targets, leave notes, and nudge her, all aimed at hitting **9.5 SGPA**.

## 2. Who it's for

| Role | Who | What they do |
|------|-----|--------------|
| **Student** | Your girlfriend | Logs attendance, marks, tasks, follows the timetable, watches her 9.5 progress |
| **Advisor** | You | Views all her data, assigns/tracks tasks, sets goals & targets, leaves notes, sends reminders |

The student can use the Android app or the companion web app. Advisor access is optional and is
unlocked through a **pairing code** only after both accounts choose to connect.

## 3. Core principles

1. **Goal-driven.** Every screen ladders up to the 9.5 SGPA target. The app always answers
   "Am I on track, and what do I do next?"
2. **Two phones, one shared truth.** Supabase keeps both devices in sync via Realtime; it works
   offline and catches up when back online.
3. **Clean & minimal.** Calm, distraction-free, productivity-app aesthetic. Focus over flair.
4. **Respectful transparency.** She has consented that the advisor sees everything. No hidden
   surveillance — the app makes it clear what's shared (it's all of it).

## 4. Feature set

### 4.1 Academics & the 9.5 engine (the heart)
- **Subjects** per semester, each with **credits** and a **custom assessment breakdown**
  (e.g. Quiz 10% + Assignments 15% + Mid-sem 25% + End-sem 50% — weights vary per subject).
- **Marks entry** for every assessment as they happen.
- **Live predicted grade per subject** from entered marks + weights.
- **Projected SGPA** for the semester, updated as marks come in.
- **"What you need" back-calculator:** given the 9.5 target, the app shows the minimum marks
  she needs in the remaining assessments of each subject to still reach it — and flags when a
  target becomes mathematically out of reach so the plan can adapt.
- **10-point, credit-weighted SGPA**: `SGPA = Σ(credit × gradePoint) / Σ(credit)`.
- **Multi-semester history + CGPA** trend over time.

### 4.2 Attendance
- **Per-class** attended / missed / cancelled marking (driven off the timetable).
- **75% minimum** rule per subject (threshold configurable per subject).
- **"Can I skip?"**: shows how many classes she can still miss before dropping below 75%,
  and how many she must attend to climb back above it.
- Holidays / cancelled classes don't count against her.

### 4.3 Timetable
- **Weekly recurring grid** (days × periods): subject, time, room, faculty.
- **Exceptions**: one-off changes — rescheduled class, extra class, holiday, swapped period.
- Drives attendance prompts and class reminders.

### 4.4 Calendar & events
- **Exams, quizzes, mid-sems, end-sems** — date, subject, and (optionally) max marks → feed the predictor.
- **Assignment deadlines** with reminders.
- **Holidays & college events** (fests, no-class days) that affect timetable/attendance.
- Unified month/week/agenda calendar view.

### 4.5 Tasks
- **Advisor-assigned** tasks she sees and completes; you track completion.
- **Her own** personal to-dos.
- **Recurring** tasks for study habits (e.g. "Revise DSA — 1 hr daily").
- **Linked to a subject or event** (e.g. "Prep for Physics quiz").
- Due dates, priority, done/undone state.

### 4.6 Advisor tools (your side)
- **Full read access** to her timetable, attendance, grades, tasks, notes.
- **Assign & track tasks.**
- **Set goals & targets**: the 9.5 SGPA goal, per-subject target grades, study targets.
- **Notes / feedback** on her performance that she can see.
- **Send notifications / encouragement** to her — in v1 these surface as in-app messages when
  she opens the app (true remote push is deferred until a paid Apple account exists; see §6).

### 4.7 Motivation
- **9.5 dashboard**: projected-SGPA gauge, per-subject progress bars, on-track / falling-behind status.
- **Streaks & habits**: daily study streaks and momentum counters.
- **Encouragement notes**: motivational messages you send that pop up in her app.

### 4.8 Reminders & notifications
- **Local** (on her device): class & test reminders, task-due reminders, a **daily summary**
  ("today's classes, due tasks, upcoming tests"), and **attendance nudges** when a subject nears 75%.
- **Advisor messages** (from you → her): reminders and encouragement you send. In v1 they appear
  as **in-app messages** surfaced when she opens the app. True remote push (a notification that
  pops up without opening the app) is **deferred** — it needs a paid Apple Developer account for
  iOS, which we're skipping for now (see §6).

### 4.9 Media
- **Images stored in Supabase Storage** (e.g. photos of question papers, marksheets, notes,
  timetables), scoped per student-space by Row-Level Security. Because they're in shared storage,
  **the advisor can actually see the images she adds** (the earlier "local-only" plan would have
  hidden them from you), and they survive app reinstalls. Images attach to a subject, assessment,
  note, or event.

## 5. Explicitly in scope vs later

**v1 (build first):** student auth, subjects/credits/weights, marks entry, predictor + 9.5
back-calculator, SGPA + CGPA, per-class attendance with 75% logic, weekly timetable + exceptions,
calendar with exams/assignments/holidays, tasks (all four types), advisor view + tasks + goals
+ notes, local notifications, in-app advisor messages, 9.5 dashboard, streaks, shared images via
Supabase Storage.

**Later (designed-for, not built yet):** advisor **remote push** (needs a paid Apple Developer
account + APNs key, plus FCM/OneSignal or a Supabase Edge Function), milestones/rewards,
home-screen widgets, App Store public release, richer analytics.

## 6. Constraints & realities (flagged honestly)
- **Android and web are the current targets.** Android ships as an APK; the full web app deploys
  to GitHub Pages. iOS is explicitly deferred.
- **"Completely on device" is now hybrid.** Per your decisions, the backend is **Supabase**:
  Auth + Postgres tables + Storage + Realtime live in the cloud so two phones share state and you
  can advise remotely. Supabase's offline support means the app still works without signal and
  syncs when back online.
- **Free tier is plenty.** For two users, Supabase's free tier (database, auth, storage, realtime)
  comfortably covers everything at ₹0.

## 7. Naming
Project name: **CourseCraft**.
(Folder is `Tracker_for_paru` for now; the app/project identity is CourseCraft.)
