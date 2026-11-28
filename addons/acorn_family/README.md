# Family sync add-on (`addons/acorn_family`)

The tablet side of the family platform: it pairs a tablet with a parent's
family, says which local profile is which child, uploads the play log,
backs saves up as snapshots and restores them, and fetches the parent's
settings. It calls only the `/v1` API (`docs/contract/api-v1.md`) and is
game-agnostic: the game hands it a few hooks and draws its own screens.

It does nothing until the game calls `Family.configure(hooks)`, and nothing
on the network until a grown-up pairs the tablet. Offline, unpaired or
removed from the family, the game plays exactly as before; failures are
quiet and only the PIN-guarded Family screen shows a line about them.

## Files

| File | What |
| --- | --- |
| `family.gd` | The autoload `Family` (a Node): the loop, the calls, the files. |
| `family_config.gd` | The server address (one setting) and file names. |
| `family_api.gd` | Each `/v1` call as data, and what an answer status means. |
| `family_pairing.gd` | Pairing as a state machine (start, poll every 3 s with backoff, approved or expired). |
| `family_events.gd` | Play log batches: which lines go, range names `{first_seq}-{last_seq}`, refusals. |
| `family_state.gd` | The state file and the token file, the profile-to-child map. |
| `family_limits.gd` | `daily_minutes` and `bedtime`: parsing, minutes per day, bedtime, a grown-up's pass. |
| `family_http.gd` | The transport: one `HTTPRequest` per call, 20 s timeout, never throws. |

Everything but `family.gd` and `family_http.gd` is pure and tested headless
(`tests/test_family_logic.gd`); `tests/test_family_sync.gd` runs the whole
add-on against an in-memory server (`tests/support/family_fake.gd`).

## On the device

| Path | What | Backed up? |
| --- | --- | --- |
| `user://device_token.json` | `{schema: "acorn.family_token", v, dev, token, base, at}`. The token is only used when `dev` is this install's device id and `base` is the server the build points at, so a copied folder or another build reads as unpaired. | No: Android export has `user_data_backup/allow=false`, and the device-id check covers a copied folder. |
| `user://family_state.json` | Upload position (`sent`), the batch on its way (`inflight`), consent, the family's name and children, the profile map, profiles to restore, snapshot revisions, cached settings, minutes played today, grown-up passes. | Same as above |
| `user://play_log.jsonl` (+ `.1`, `.2` ...) | The game's play log. While paired, `PlayLog.keep_after` is the upload position: a full file is never dropped while it holds unsent lines (up to `MAX_KEPT` = 8 files, about 8 MB). | |

## What happens when

- **Pairing** (Family screen, "Show a pairing code"): `POST /devices/pair/start`,
  the code is shown large, `GET /devices/pair/poll` every 3 s (slower after a
  minute, slower again while offline) until approved or expired (also a 404).
  The approved token goes in `device_token.json`. Consent starts **off**.
- **Who is who**: each local child profile maps to a family child, `"new"`
  (`PUT /devices/{dev}/profiles` with `"child": "new"`, nickname and picture;
  the server makes the child and lists it in `created`) or nothing. A Guest is
  never sent. `GET /devices/{dev}/profiles` on launch and resume picks up
  children added or removed in the parent app.
- **Sync**: shortly after launch, on resume, after a run or level ends and
  every 5 minutes. In order: the profile map, restores, settings, then (only
  with consent) snapshots and the play log. A failed sync backs off 30 s, 1,
  2, 4 ... up to 30 minutes.
- **Play log upload** (consent on): lines after `sent`, this device's only,
  Guest lines never (the roster's Guest and any profile a `profile_picked`
  line marks as guest), up to 500 lines a batch, gzipped, at
  `PUT /events/{game}/{dev}/{first_seq}-{last_seq}`. The range is saved as
  `inflight` before it is sent, so a lost answer resends the same range and the
  server answers "duplicate". `sent` moves only after a 2xx. A 400 or 413
  splits the batch in half; a single refused line is skipped (counted in
  `skipped`). If the server says the gzip is bad, it falls back to plain text.
- **Snapshots** (consent on): 15 s after the last save write (at most 2
  minutes after the first), `PUT /children/{child}/games/{game}/snapshots/{dev}`
  with `rev` one past the last one sent; a `409 {stored_rev}` jumps past it.
- **Restore**: when a profile is linked to an existing child, or on "Restore
  from parent app": `GET .../snapshots`, the game's merge (`SaveData.merge`)
  with the local save, written back (the old file kept as
  `profile_<id>.before_restore.json`), then backed up.
- **Settings**: `GET .../settings` for each linked child on launch, resume,
  after linking and every 30 minutes; kept in the state file for offline play.
- **Removed**: any device call answered 401, 403 or 410 drops the token and
  the family's things (map, children, settings, consent) and the tablet plays
  on unpaired. The upload position and minutes played stay. "Unlink this
  tablet" does the same locally.

## The game's hooks

```gdscript
Family.configure({
	"game": "acorn-math", "dev": dev, "app": "0.29.0", "code": 48,
	"roster": func() -> Array,            # [{id, nickname, picture, guest}]
	"active_profile": func() -> String,   # minutes count for them
	"read_save": func(profile) -> Dictionary,
	"write_save": func(profile, save),    # a restore writes the merged save
	"snapshot": func(save, dev, rev, now, child) -> Dictionary,  # family.snapshot
	"merge": func(snapshots, profile, local_save) -> Dictionary,
	"saved_at": func(profile) -> int,     # 0 for a save with nothing in it
	"log_files": func() -> Array,         # oldest first
	"last_seq": func() -> int,
	"keep_log_after": func(seq),          # -1 when unpaired
})
```

Acorn Mathematics builds them in `game/family_glue.gd`; its screens are
`game/family_screen.gd` (Grown-ups, Family) and `game/rest_screen.gd`.
Call `Family.save_written(profile)` after a save write (Acorn:
`SaveStore.written`), `Family.poke()` when a run ends,
`Family.stop_reason(profile)` at safe points (`"daily"`, `"bedtime"` or `""`),
and set `Family.counting` off on screens that are not play.

## Pointing at staging or production

One setting, in this order:

1. the environment variable `ACORN_FAMILY_URL` (desktop runs, the e2e script),
2. the project setting `acorn_family/base_url` in `project.godot`,
3. `FamilyConfig.DEFAULT_BASE_URL`, staging:
   `https://maphrtpqbqmjfmhgqonq.supabase.co/functions/v1/api/v1`.

For a production build, set `acorn_family/base_url` to the production `/v1`
address (`https://api.<domain>/v1` once the domain exists). A token belongs
to the server it was made on, so switching a tablet's build between staging
and production means pairing again.

## Testing

```sh
godot --headless --path . --script tests/run_tests.gd        # everything, no network

python3 -I tools/family_mock/server.py &                     # a local /v1 from the samples
ACORN_FAMILY_URL=http://127.0.0.1:8787/v1 \
  godot --headless --path . --script tools/family_e2e/e2e.gd  # pair, map, upload, snapshot, settings, restore
```

The mock approves a pairing on its second poll (`--manual` waits for
`POST /v1/devices/pair/approve {"code": "..."}`), checks event lines and
snapshots against the contract schemas, and shows everything it holds at
`GET /mock/state`.

Against staging, approve the code in the parent app when the script prints
it, or let the script do it with a parent's access token:

```sh
ACORN_FAMILY_URL=https://maphrtpqbqmjfmhgqonq.supabase.co/functions/v1/api/v1 \
ACORN_E2E_APPROVE_CMD='curl -s -X POST "$ACORN_FAMILY_URL/devices/pair/approve" \
  -H "Authorization: Bearer $PARENT_TOKEN" -H "Content-Type: application/json" \
  -d "{\"code\":\"{code}\",\"device_name\":\"E2E tablet\"}"' \
  godot --headless --path . --script tools/family_e2e/e2e.gd
```

Each run is a new device (a random id) and a new child named "E2E Kid" in
that family; remove them in the parent app afterwards. Stills of the screens:
`xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/sync_stills.tscn -- --out=/tmp/shots`.
