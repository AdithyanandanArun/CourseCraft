# CourseCraft Android

CourseCraft is an Android-first student academic tracker with optional advisor coaching. Core
student workflows never depend on pairing an advisor.

This repository is the Flutter Android application and the canonical location for Supabase
migrations. The companion React web app is maintained in the separate public `CourseCraft-Web`
repository. The cross-platform roadmap is in the workspace root `Plan.md`.

## Source Map

- `Idea.md` - product scope and constraints.
- `ANDROID_PLAN.md` - Android-specific delivery guide.
- `scripts/bootstrap_phase0.sh` - creates the Android Flutter app in place and installs dependencies after Flutter/Android SDK are available.
- `supabase/migrations/0001_init.sql` - initial Supabase schema, RLS policies, pairing RPC, and attachments bucket policies.

## Bootstrap

```bash
bash scripts/bootstrap_phase0.sh
```

## Supabase configuration

Apply every file in `supabase/migrations/` to one Supabase project, in filename order. The Phase 1
migration provisions a profile for every new account and a private student space for student roles.
Then launch with the project URL and anonymous key supplied as Dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The app shows a configuration state instead of attempting a connection when either value is absent.
