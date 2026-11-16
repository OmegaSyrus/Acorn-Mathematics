# Acorn Mathematics in the contract

- Game id: `acorn-math` (permanent).
- Save: `acorn.save` version 2, `save.v2.schema.json`. One file per profile,
  `user://profile_<profile id>.json`.
- Profile pictures: the hero art ids in `art/heroes/` (`fox`, `bunny`,
  `hedgehog`, `turtle`, `lion`, `eagle`, `phoenix`, `gryphon`, `elf_mage`,
  `templar`, `slime_knight`).
- Manifest: built from content by `logic/core/manifest.gd`
  (`samples/manifest.json` is its output for 0.24.0, code 43).

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
| `run` | this device's own; never taken from another device |
| anything unknown | from the newest snapshot that has it |
