# Ellwynn in the game: main menu intro and cue plan (draft 2, 2026-11-06)

A plan. Only the three placeholder voice lines have been made (section 3). No art has been made.
The look and voice come from `/mnt/project-files/sum-dungeon/Ellwynn-Character-Bible.md`,
which wins if this page disagrees with it.

## 1. The rule: she is mostly a voice

Terrence, 2026-11-06: "she should generally be a voice". So during play she is
heard, not seen. She shows up on screen only at these moments:

| Moment | Seen? | What she does |
|---|---|---|
| Main menu, first visit | Yes, full body | Says hello and explains the game (section 3). |
| Main menu, later visits | Yes, full body, quiet | Stands in her spot. One short greeting. Tap her to hear the explanation again. |
| Enemy beaten | **Sometimes** (about 1 in 3) | Her 96 px bust pops into the bottom-left corner for about 1.2 s with a quick cheer and pops out. The other times she only speaks, or says nothing. |
| Treasure chest opened | No, voice only | A short word of encouragement. Not every chest, so it stays special. |
| Region boss beaten | Yes, full body | She walks or slides in beside the hero and congratulates the player, with a longer line. This is her big moment. |
| Reading questions ("Which stone is safe?") | No, voice only | Reads the talk box text aloud. |

She never covers the dice tray, the stones or the Go button, and the child can
always keep playing while she talks: tapping on with the game cuts her line off.

## 2. Where she stands on the main menu

The main menu today is the map screen (`game/map_screen.gd`): "Lava Caves" at
the top, the grade button ("Acorn") in the middle at y 230, the green "Go"
resume button below it, and the purple Shop button bottom right (x 624..824).
The bottom left of the 4:3 band (x 120..380) is empty apart from the small
"stickers" text.

- **Her spot:** the full body (`ellwynn-fullbody-160x256.png`, the C2 final) standing
  bottom left, feet on the bottom edge, at about x 150..310, y 284..540. That is
  1 art pixel = 1 unit like every other character, never scaled. The stickers
  text moves up or right.
- **Idle:** a gentle 2 px bob, the locket glows on a slow pulse, and she blinks
  every 3 to 5 s (one hand-made blink frame).
- **When the difficulty plan lands** (6 levels per world, its own thread), the
  level buttons should stay right of x 380 so her spot is kept. That thread
  owns the button layout; this plan only asks for the space.

### How she reacts to the buttons

| Tap | Her reaction | Line |
|---|---|---|
| A grade or level (Play) | Hops once and points the way | Sheet point M3 |
| Go (resume) | Hops once | Sheet point M4 |
| Shop | Leans toward it, locket flares | Sheet point M5 |
| Back from the Shop | Small wave | Sheet point M6 |
| Menu button (top right, in play) then Main Menu | Already standing in her spot when the map comes back | Sheet point M2 |
| Ellwynn herself | Turns to the child | Replays the explanation (M1) |

The hop, lean and wave are code motion on the one approved image (move, squash,
a tilt of a few degrees), so they cost nothing. A real pointing or waving pose
would be new art; see the questions.

The two-tap rule still applies to the play buttons where it applies now, so a
tap on Play starts her line and the game swaps screens when the line ends or
after 1 s, whichever comes first.

## 3. Her lines: placeholders now, Terrence and Rachel write the real ones

Terrence, 2026-11-06: "we'll write the lines, you give us the situation and the
context, point by point". The situations are in the separate sheet
**`docs/ellwynn-lines-sheet.md`**, one point per moment, each with what is on
screen, what the child just did, how long the line can be, and how many
variants are worth having.

Until a point's real line is written, the game plays one of three generic
placeholders that fit any moment (generated 2026-11-06 in the Bubbles voice,
eleven_v4, 2 takes each, about 107 credits in all):

| Placeholder | Takes |
|---|---|
| "Yay!" | `yay-1.mp3`, `yay-2.mp3` |
| "Woo-hoo!" | `woohoo-1.mp3`, `woohoo-2.mp3` |
| "Let's go!" | `letsgo-1.mp3`, `letsgo-2.mp3` |

They are in `/mnt/project-files/sum-dungeon/ellwynn-intro/placeholder-voice/`.
Each sheet point falls back to a random placeholder while its own line is
missing, so lines can be swapped in one at a time as they are written and
generated. The explanation itself (M1) has no placeholder that makes sense, so
until it is written, tapping her just plays a placeholder.

A small queue makes sure she never talks over herself, and the music ducks
about 10 dB while she speaks (`game/music.gd` already leaves room for this).


## 4. Talking: mouth frames

- **Frames:** 2 or 3 hand-made mouth frames on top of the approved art:
  closed (the existing small closed smile), half open, and open. Plus one blink
  frame. These are small pixel edits on the face only, done by hand in Aseprite
  (Terrence's final touch-up) or by me as free pixel edits for Terrence to check.
  They are needed on two images: the full body (where the mouth is only a few
  pixels wide, so 2 frames may be enough) and the 96 px bust.
- **Timing:** each voice file gets a small mouth track made offline by a script:
  it measures the loudness of the audio every 1/15 s and picks closed, half or
  open. The track ships as a small JSON next to the audio, so the game just
  plays it back in time with the sound. No lip-sync tool is needed for this.
- **Tools:** RetroDiffusion does no lip-sync. **Correction to our earlier note:**
  PixelLab now has a mouth tool (`create_vocal_animation`) that makes mouth
  frames for a bust portrait up to 256 px, driven by text rather than audio.
  Its docs list about 6 plan generations at 128 px and 24 at 256 px, out of the
  roughly 10,000 a month on the plan, so it is close to free. It does not work
  on a full body sprite, and it would redraw her face, so it would need checking
  against the 12 fixed details. I suggest hand-made frames first, and the
  PixelLab tool only if the hand-made ones look stiff.


## 5. Voice: production steps and cost

**Voice:** ElevenLabs Bubbles, id `cl7Lq9M5lHPrBM5kbtI6`, model eleven_v4.
Save it to My Voices first, so the owner cannot withdraw it from under us.

**Steps (per line, as each one is written):**

1. Terrence and Rachel write the line for a sheet point.
2. Generate it with 2 takes. Terrence picks the take.
3. Trim silence, normalise loudness, and export as OGG for Godot (about 20 KB a line).
4. The script makes the line's mouth track (section 4).
5. The file goes in `audio/voice/ellwynn/<point>-<n>.ogg` and is listed in
   `content/ellwynn_lines.json`, replacing the placeholder for that point.

**Cost:** Terrence's ElevenLabs plan is about $20 a month (the Creator plan is
$22 with about 100,000 credits). Measured on 2026-11-06, a short line costs
14 to 20 credits a take, so the three placeholders with 2 takes each came
to about 107 credits, roughly 2 cents of the month's credits. The whole sheet
(about 60 lines, 2 takes each, plus retakes) should need at most about 3,000
credits, around 3% of one month, so **no extra spend beyond the plan he already
pays for**. The plan includes the commercial licence needed for Steam and Xbox.


## 6. Build order (once the questions are answered)

1. Ellwynn node with idle bob, blink and mouth track playback (no new art, using placeholders for the extra frames).
2. Main menu spot, intro, replay, button reactions, save flag.
3. Voice queue and music ducking.
4. In-play cues: enemy "yay" pop-in, chest voice, boss congratulation, questions read aloud.
5. Generate each real line as it is written, and make the mouth frames.


## 7. Questions for Terrence

1. **Main menu:** is the full body standing bottom left right, or would you rather have the 96 px bust in a corner there too?
2. **Pose:** are code moves (hop, lean, wave-like tilt) on the one approved image enough for now, or do you want a real pointing or waving pose? That would be new art, PixelLab first.
3. **Mouth frames:** shall I make the 2 or 3 mouth frames and the blink as free hand edits for you to check, or will you draw them in Aseprite?
4. **How often:** is "about 1 in 3 enemies" right for the quick "Yay!" pop-in, and should every chest get a line or only some?
5. **Boss win:** should she appear full body beside the hero when a region's boss is beaten?
