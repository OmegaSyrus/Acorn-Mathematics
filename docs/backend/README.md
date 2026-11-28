# Family backend (not built yet)

The shared backend for every game: parent sign-in, families, children,
devices, pairing, event upload, snapshots, settings, reports, delete and
export. It follows the parent app plan v2 and the data contract in
`docs/contract/`.

**Where it lives:** OmegaSyrus/Acorn-Backend (Terrence, 2026-11-17). Its
`contract/` is the source of truth; `docs/contract/` here is the game's
copy, which its tests read. Backend core is Acorn-Backend PR #1 and the
parent app is its `web/`. The sync add-on (the tablet side) lives in this
repo at `addons/acorn_family/` (see its README; grown-ups' view in
`docs/family-sync.md`); another game copies that folder in.

## Stack

| Part | Service | Notes |
| --- | --- | --- |
| Parent sign-in | Supabase Auth | email link and Google first; Apple, Microsoft/Xbox, Steam with their ports |
| API | Supabase Edge Functions, `/v1` | the only thing games call (`docs/contract/api-v1.md`) |
| Database | Postgres with row-level security | families, adults, children, devices, profile-to-child index, settings, upload index, daily rollups, consent records |
| Files | Supabase Storage | raw event batches, snapshots, manifests |
| Jobs | scheduled functions | weekly email, rollup rebuilds, retention deletes |
| Parent app | static site | talks to Supabase directly, limited by row-level security |

Free plan while building (it pauses after a week idle), Pro ($25 a month)
once real families use it, Canada region. Staging uses the project's free
`supabase.co` address until the domain exists.

## Tables (first cut)

```text
families      (id, created_at, region)
adults        (id = auth.users.id, family_id, role: owner|caregiver|viewer, email)
identities    (adult_id, provider, provider_uid)          -- a sign-in is a row
children      (id 'c_…', family_id, nickname, birth_year?, picture, created_at, deleted_at?)
devices       (id 'd_…', family_id, game, name, token_hash, paired_at, last_seen, removed_at?)
profiles      (dev, profile 'p_…', child_id?, nickname, picture, guest)  -- the profile-to-child index
settings      (child_id, game, key, value jsonb, rev, at, by)
uploads       (game, dev, first_seq, last_seq, path, bytes, received_at)
snapshots     (child_id, game, dev, rev, path, saved_at, received_at)
manifests     (game, code, path, received_at)
rollups_daily (child_id, game, day, skill, tries, right, seconds)
consents      (family_id, version, method, at, adult_id)
pair_requests (id, code, game, dev, expires_at, approved_by?, device_token?)
```

Row-level security: an adult sees only rows of their own family; device
tokens reach only their own device's rows through the Edge Functions (the
service key never leaves the functions).

## What the game already does (groundwork, this repo)

- A random device id per install, not carried by backup (`game/device_id.gd`).
- Child profiles on the device with a "Who is playing?" picker and a Guest
  (`logic/core/profiles.gd`, `game/profile_store.gd`, `game/who_screen.gd`).
- A parent PIN on the Grown-ups panel, hashed on the device.
- Save format version 2 with per-device gem counts and a merge for restores
  (`logic/core/save_data.gd`).
- Play log version 2 lines with game, device, profile, sequence and skill.
- A manifest built from content (`logic/core/manifest.gd`).
- Everything plays offline with no account, exactly as before.
- The sync add-on (`addons/acorn_family/`): pairing, who is who, uploads,
  snapshots, settings and time limits, all behind the parent PIN.

## Order of work

1. Contract (this PR). Samples validate in CI.
2. Game groundwork (this PR).
3. Backend core in the platform repo: accounts, email-link and Google
   sign-in, families, children, devices, pairing, tokens, consent record,
   delete and export, staging and production deploys. Done when the
   contract's sample calls pass against staging.
4. Sync add-on (`addons/acorn_family/`, built 2026-11-28), against a mock
   server built from the samples first (`tools/family_mock/server.py`, with
   `tools/family_e2e/e2e.gd` running every step over HTTP): pairing screen,
   uploader, snapshot backup and restore, settings fetch and apply (daily
   minutes, bedtime). Ships switched off until a family pairs, and sends
   nothing until a grown-up turns sending on.

## Decided (Terrence, 2026-11-17)

Supabase; email link and Google first; 24 months after last play;
backend in OmegaSyrus/Acorn-Backend. Still his to-do: name and domain.
