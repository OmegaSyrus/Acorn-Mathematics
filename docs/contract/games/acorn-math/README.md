# Acorn Mathematics in the contract

- Game id: `acorn-math` (permanent).
- Save: `acorn.save` version 2, `save.v2.schema.json`. One file per profile,
  `user://profile_<profile id>.json`.
- Profile pictures (2026-11-21, profile plan C1): the 14 hero looks from the
  store (`content/store.json`, items of kind `hero`), the manifest's
  `pictures` list, in the game's order (`Profiles.PICTURES`):
  `robodragon` (Bolt), `bolt_red` (Red Bolt), `bolt_green` (Green Bolt),
  `fox` (Rusty), `bunny` (Nutkin), `hedgehog` (Spike), `turtle` (Shelly),
  `lion` (Leo), `eagle` (Talon), `phoenix` (Blaze), `gryphon` (Griff),
  `elf_mage` (Rowan), `templar` (Sir Tam), `slime_knight` (Sir Blob).
  A picture is only a picture: it does not unlock or equip that hero. Red and
  Green Bolt are Bolt's sprite repainted in code (`game/ui/look.gd`); the
  parent app keeps ready-made copies in `web/pictures/acorn-math/`. Older
  rosters may still hold any of the 11 earlier ids, which are all in this list.
  The server accepts any id of `[a-z0-9_]{1,32}`, so a new look needs no
  backend change, only its PNG in `web/pictures/acorn-math/`.
- Manifest: built from content by `logic/core/manifest.gd`
  (`samples/manifest.json` is its output for 0.28.0, code 47, with
  `picture_labels` added by hand until `manifest.gd` emits them).

## Grown-up controls (time limits)

Agreed 2026-11-28 for the sync add-on (Phase 5): the manifest's `settings`
list holds two keys, both `scope` `child_game` (they follow the child to every
tablet), with `since_code` the first build that has the sync add-on:

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `daily_minutes` | `int`, 0 to 240 | `0` | Minutes of play a day on all tablets together; `0` is no limit. When time is up the game lets the current level finish, then says goodbye until tomorrow (the tablet's local midnight). |
| `bedtime` | `time` `HH:MM` or `null` | `null` | No new play after this time on the tablet's clock, until 06:00. |

The parent app draws them from the manifest; the game reads them with
`GET .../settings` and applies the newest value. Nothing here unlocks a world
or changes a Level. `samples/manifest.json` shows them.

## Upgrading a version 1 save

Version 1 lived in `user://profile_1.json` with `"profile": "1"`. On the
first launch of a version 2 build:

1. The roster (`user://profiles.json`) is made with one profile, a new
   random `p_` id, nickname "Player 1" and the picture `fox`.
2. The old save is read through `SaveData.from_text`, given that id,
   `schema`, `version: 2`, `game`, and `gem_counts` with its whole balance
   as this device's earned gems, then written to `user://profile_<id>.json`.
3. `profile_1.json` is renamed `profile_1.v1.json` and kept, so nothing is
   lost if a later build needs it.

## Merging snapshots on restore

When the sync add-on restores a child on a device, it downloads every
device's snapshot for that child and merges them with `SaveData.merge`:

| Field | Merge |
| --- | --- |
| `marks`, `stars` | union per world, sorted |
| `owned` | union |
| `stickers` | each sticker as many times as the most any one snapshot has it |
| `gem_counts` | per device, the highest `earned` and the highest `spent` |
| `gems` | sum of earned minus sum of spent |
| `currencies` | per currency, the highest (no spending yet) |
| `hero`, `dice`, `difficulty` | from the newest snapshot (`saved_at`) |
| `ellwynn_intro_seen` | true if any is true |
| `taught` | per cue id, true if any is true |
| `book` | per monster id, the union of the Levels (like `marks`) |
| `run` | this device's own; never taken from another device |
| anything unknown | from the newest snapshot that has it |
