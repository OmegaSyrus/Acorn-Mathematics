# Dropping in Ellwynn's lines, sounds and songs (Phase 3)

Everything here works by putting files in a folder and rebuilding the APK. No code
changes, no lists to edit.

## Ellwynn's lines

1. Record the line (ElevenLabs, voice Bubbles `cl7Lq9M5lHPrBM5kbtI6`).
2. Name the file by its **cue id** from the lines sheet
   ("Ellwynn's lines: where she speaks"), and put it in **`audio/voice/lines/`**.
3. Optional: `python3 -I tools/voice/mouth_tracks.py` so her mouth follows the line
   exactly (without it, the mouth follows the loudness as it plays).
4. `python3 -I tools/voice/check_lines.py` shows what is covered and flags any file
   whose name matches no cue.
5. Rebuild the APK (`tools/android/build_apk.sh`).

| What | File names |
| --- | --- |
| One take | `T2.mp3` |
| More takes (she picks one at random, never the same twice running) | `P3.mp3`, `P3_2.mp3`, `P3_3.mp3` ... |
| The intro's seven parts, played in order | `M1.mp3`, `M1_2.mp3` ... `M1_7.mp3` |
| The two boss tips, played in order | `T14.mp3`, `T14_2.mp3` |
| A line per world (boss appears, boss beaten) | `B1-lava.mp3`, `B1-crystal`, `B1-bog`, `B1-mushroom`, `B1-space`; the same for `B2-...` |
| Cheerful numbers after a miss (already made; a file here replaces the old one) | `A0.mp3` ... `A20.mp3` |
| Plain counting numbers ("four", not "Four!") | `Q0.mp3` ... `Q20.mp3` (until they exist, counting uses the A takes) |
| The cheer after the number on a right stone (replaces "Woo-hoo!") | `C3.mp3`, `C3_2.mp3` ... |

`.mp3`, `.ogg` and `.wav` all work, and upper or lower case doesn't matter
(`t2.mp3` is T2).

The full list of cue ids, with when each fires, how many takes it wants and what
plays while it has no file, is `content/ellwynn_cues.json` (made by
`tools/voice/make_cues.py` from the sheet).

### What plays before a line is recorded

Each cue has a fallback:

- **placeholder**: one of the three stand-ins ("Yay!", "Woo-hoo!", "Let's go!"),
  as before. Used for cheers: welcome, Play, Shop, chest, monster beaten, boss beaten.
- **stand-in voice**: the tablet's own text-to-speech reads a few plain words, mostly
  the words on screen ("Roll!", "Which stone is safe?"). This is only so a child can
  play and be taught before the real lines exist; the words are not Ellwynn's lines.
  **Debug > Voice** turns it off (then these cues are quiet).
- **quiet**: nothing.

As soon as a file with the cue's id is in the folder, it plays instead.

### Taught lines (T1 to T15, N1 to N11)

Each plays once per child, the first time it happens, then never again for that
child. Reset clears it. The game waits at each taught step until the child does it.

## Sound effects

Every sound has an id (`roll`, `gem`, `block`, `win`...). The list of ids, what
each sounds like and where it plays is **`audio/sfx/README.md`**.

1. Name the file by the sound's id and put it in **`audio/sfx/`**
   (not in `audio/sfx/builtin/`, which holds the built-in ones).
2. Rebuild the APK.

| What | File names |
| --- | --- |
| One sound | `win.mp3` |
| More takes (one at random, never the same twice running) | `roll.ogg`, `roll_2.ogg`, `roll_3.ogg` ... |

`.mp3`, `.ogg` and `.wav` all work, upper or lower case. A file here replaces all
the built-in takes of that id. Take the file out and the built-in sound comes back.
For `count`, `gem`, `coin` and `mallet`, give one clear note (A4 for `count` and
`mallet`, C6 for `gem` and `coin`): the game raises it per number or gem.

The built-in sounds are made by `python3 -I tools/sfx/make_sfx.py` (synthesized,
nothing to license).

## Music

Each world plays every song in its own folder, shuffled, never the same twice
running:

| Folder | Plays |
| --- | --- |
| `audio/music/menu/` | the main menu, looping |
| `audio/music/lava_caves/` | Lava Caves |
| `audio/music/crystal_mines/` | Crystal Mines |
| `audio/music/bog/` | the Bog |
| `audio/music/mushroom_forest/` | Mushroom Forest |
| `audio/music/space/` | Space |

Any file name works (`.mp3`, `.ogg` or `.wav`). A world whose folder is empty plays the
Lava songs (and two such worlds share them, so the song carries on between them).
One menu song loops seamlessly; several menu songs shuffle. Suno exports `.mp3`,
which is fine as it is. Rebuild the APK after adding songs.
