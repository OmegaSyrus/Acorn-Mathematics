# Family data contract, v1

The shapes every game, the backend and the parent app agree on: what a game
writes on the device, what it uploads, what it downloads and what it
publishes about itself. It follows the parent app plan v2 (2026-11-16):
Supabase backend, parents sign in, devices pair with a code, everything is
filed per child per game, latest change wins for settings, no end-to-end
encryption, no remote Level or world unlock.

This folder lives in the game repository until the platform repository
exists (name and domain are Terrence's to-do). It then moves to that repo's
`contract/` unchanged, and the game keeps a copy that its tests read.

| Path | What it is |
| --- | --- |
| `schemas/*.schema.json` | JSON Schema (draft 2020-12 subset, see below) for each document |
| `samples/` | One good sample per document. Every test (game, backend, parent app) reads these |
| `skills.json` | The shared skill list. Every answer names one skill id from it |
| `api-v1.md` | The `/v1` API the games call |
| `retention.md` | What is kept, for how long, and how delete and export work |
| `games/acorn-math/` | What only Acorn Mathematics defines: its save format inside a snapshot |

## Documents

| Schema name | Version | Where it lives | Who writes it |
| --- | --- | --- | --- |
| `family.event` | 2 | `user://play_log.jsonl` on the device, uploaded in batches | the game |
| `family.device` | 1 | `user://device.json`, never uploaded as a file | the game |
| `family.profiles` | 1 | `user://profiles.json`, never uploaded as a file | the game |
| `family.snapshot` | 1 | uploaded per device per child per game | the game |
| `family.settings` | 1 | the server, one per child per game | parent app and game |
| `family.manifest` | 1 | the server, one per game version code | the game's build |
| `acorn.save` | 2 | `user://profile_<profile id>.json`, inside a snapshot | Acorn Mathematics |

Every document except an event line carries `"schema"` and `"v"`. An event
line carries `"v"` only, to keep lines short; its schema is implied by the
file.

## Rules that keep the system safe against change

1. **Add, never rename or retype.** A new need is a new field. A field no
   longer used is ignored but kept in the schema, marked `"deprecated": true`.
2. **Readers keep what they don't know.** A game that reads a document with
   fields it doesn't know writes them back unchanged. Schemas allow extra
   properties for this reason.
3. **Every document is versioned.** Readers upgrade old versions on read
   (`SaveData.from_text` in the game is the one upgrader for saves). Stored
   raw events are never rewritten; the server reads every event version ever
   shipped.
4. **Ids are permanent and never reused**: game, world, level, skill, child,
   device, profile. Level ids in `content/levels.json` are never renumbered.
5. **Skills, not positions.** Reports work from `skill` ids, so reordering
   levels or adding worlds does not break history.
6. **Change the contract first**, in its own pull request with updated
   samples. Game, backend and web follow.

## Ids

| Id | Format | Made by | Example |
| --- | --- | --- | --- |
| game | lowercase words and dashes, fixed forever | us | `acorn-math` |
| device (`dev`) | `d_` + 16 hex, random at first launch | the game | `d_7f3a9c1e04b25d68` |
| profile | `p_` + 12 hex, random when a profile is made | the game | `p_04a2c9e1f3b7` |
| child | `c_` + 12 hex, random | the server, at pairing | `c_9b2f00e1a7c4` |
| family | uuid | the server | |
| seq | integer from 1, +1 per event line, per device | the game | `10432` |

A device is one install of one game. Its id is in `user://device.json`
together with a fingerprint of the hardware id (`OS.get_unique_id()`,
hashed). If Android backup or a copied folder brings the file to another
tablet, the fingerprint no longer matches and the game makes a new device
id there, so two tablets never upload as one. The old id is kept as
`"copied_from"` for support.

A profile is one "Who is playing?" entry on one device. The server keeps a
separate index of which profile is which child (`PUT /v1/devices/{dev}/profiles`),
so a wrong match is fixed without rewriting events. A Guest profile
(`"guest": true`) plays and saves locally but never syncs.

## The schema subset

Schemas use only: `type`, `properties`, `required`, `items`, `enum`, `const`,
`pattern` (strings only), `minimum`, `maximum`, `oneOf`, `additionalProperties` (as a schema),
`$ref` to `#/$defs/...`, a list of types such as `["string", "null"]`,
`description` and `deprecated`. The game's tests and `tools/contract/check.py`
implement exactly this subset with no dependencies, so any full JSON Schema
validator agrees with them.

## Checking

- `python3 -I tools/contract/check.py` validates every sample against its
  schema (runs in CI).
- The game's Godot tests (`tests/test_contract.gd`) build a real event line,
  device file, roster, snapshot and manifest and validate them against the
  same schemas.
