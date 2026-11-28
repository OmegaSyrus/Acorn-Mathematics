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
| The two boss tips, one at a time (1 before the first pick, 2 before the first shot) | `T14.mp3`, `T14_2.mp3` |
| A line per Level, after "Level complete" (L3) | `L4.mp3` (or `L4_1.mp3`) for Level 1, `L4_2.mp3` ... `L4_6.mp3` |
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
child. Reset clears it, and so does **Debug > Teach again** (only the taught
lines, for the child playing now; nothing else in the save changes). The game
waits at each taught step until the child does it.

The boss tip T14 is taught one take at a time (`Ellwynn.teach_take`): take 1
("pick the number") the first time the boss's picks open, take 2 ("aim") the
first time the child aims. They are marked separately (`T14` and `T14_2` in the
save), so a child who first meets the boss at Acorn, where the ball takes the
number by itself and there is no pick, still hears the pick tip at the first
boss that has one. Without a recording the stand-in voice reads the matching
half of the stand-in words.

### Where the menus, map, shop and boss speak

Each screen says what to do when it opens, so a child who can't read hears it.
A tap on the screen's title or talk text ("Who is playing?", "Pick", "Name",
"Level N" on the map, "Pick" and "No more balls" on the boss board) says the
prompt again. A tap on any main menu button cuts her off.

| Screen | Cues |
| --- | --- |
| Who is playing? | K1 opens; K2 a child taps their picture (then the menu skips its welcome) |
| New child (Pick, Name, Yes) | K3 Pick step, K4 Name step; K5 saved, then the intro |
| Main menu | M1 first time, M2 later; M3 Play, M5 Shop, M7 Level; M6 back from the Shop (the welcome until M6 is recorded) |
| World map | P1 opens; P2 a locked world tapped. After a boss: L2 first clear, L1 a world opens, L5 a replay; a finished Level: L3 then L4 for that Level |
| Shop | P13 opens (after M5); S1 bought, S2 a grey Buy, S3 Use |
| Boss | B1 the boss appears (not again on Try), T14 tips, P11 each pick, B4 new pegs / a combo / a big bucket, B2 won, B3 then P12 lost |

The grown-up screens (Grown-ups, PIN, Children, Edit, Reset, Debug) are silent:
she stops when one opens.

## Sound effects

Put a file named by the sound's id in **`audio/sfx/`** to replace the built-in one
(ids and what they are: `audio/sfx/README.md`).

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
Lava songs. Suno exports `.mp3`, which is fine as it is.
