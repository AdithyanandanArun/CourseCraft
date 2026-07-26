# CourseCraft

CourseCraft is a two-person academic coaching app: one student and one advisor, sharing a single academic workspace aimed at a 9.5 SGPA target.

Current state: planning docs, Supabase Phase 0 schema, and a Flutter bootstrap script are present. The Flutter app skeleton has not been generated yet.

## Source Map

- `Idea.md` - product scope and constraints.
- `Plan.md` - phased execution roadmap and planned architecture.
- `scripts/bootstrap_phase0.sh` - creates the Flutter app in place and installs dependencies after Flutter/Android SDK are available.
- `supabase/migrations/0001_init.sql` - initial Supabase schema, RLS policies, pairing RPC, and attachments bucket policies.

## Bootstrap

```bash
bash scripts/bootstrap_phase0.sh
```

After bootstrap, continue with the Phase 0 app shell described in `Plan.md`.
