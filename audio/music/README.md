# Music

Each playlist is a folder. Drop song files in; no code or lists to edit.

| Folder | Plays |
| --- | --- |
| `menu/` | the main menu, looping |
| `lava_caves/` | Lava Caves |
| `crystal_mines/` | Crystal Mines |
| `bog/` | the Bog |
| `mushroom_forest/` | Mushroom Forest |
| `space/` | Space |

- Any file name works; `.mp3`, `.ogg` or `.wav` (Suno's `.mp3` is fine as it is).
- A world plays every song in its folder in a random order, never the same song
  twice running.
- A world whose folder is empty plays the Lava Caves songs. Two such worlds share
  that list, so walking from one to the other doesn't restart the song.
- The menu loops: one song loops seamlessly; with several, they shuffle like a world.
- The folder names are the world ids in `content/worlds.json`. The `.gitkeep` files
  only keep the empty folders in git.

Rebuild the APK after adding songs (`tools/android/build_apk.sh`).
Code: `game/music.gd`.
