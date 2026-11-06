# Ellwynn in the game: main menu intro and cue plan (draft 1, 2026-11-06)

A plan only. No art or audio has been made for it, and nothing has been spent.
The look and voice come from `/mnt/project-files/sum-dungeon/Ellwynn-Character-Bible.md`,
which wins if this page disagrees with it.

## 1. The rule: she is mostly a voice

Terrence, 2026-11-06: "she should generally be a voice". So during play she is
heard, not seen. She shows up on screen only at these moments:

| Moment | Seen? | What she does |
|---|---|---|
| Main menu, first visit | Yes, full body | Says hello and explains the game (section 3). |
| Main menu, later visits | Yes, full body, quiet | Stands in her spot. One short greeting. Tap her to hear the explanation again. |
| Enemy beaten | **Sometimes** (about 1 in 3) | Her 96 px bust pops into the bottom-left corner for about 1.2 s with a quick "Yay!" and pops out. The other times she only speaks, or says nothing. |
| Treasure chest opened | No, voice only | A short word of encouragement ("Ooh, gems!"). Not every chest, so it stays special. |
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

| Tap | Her reaction | Voice (draft) |
|---|---|---|
| A grade or level (Play) | Hops once and points the way | "Let's go!" |
| Go (resume) | Hops once | "Back we go!" |
| Shop | Leans toward it, locket flares | "Ooh, shiny!" |
| Back from the Shop | Small wave | "Nice pick!" (only if something was bought) |
| Menu button (top right, in play) then Main Menu | Already standing in her spot when the map comes back | "Welcome back!" |
| Ellwynn herself | Turns to the child | Replays the explanation |

The hop, lean and wave are code motion on the one approved image (move, squash,
a tilt of a few degrees), so they cost nothing. A real pointing or waving pose
would be new art; see the questions.

The two-tap rule still applies to the play buttons where it applies now, so a
tap on Play starts her line and the game swaps screens when the line ends or
after 1 s, whichever comes first.

## 3. The explanation script (draft for Terrence and Rachel to rewrite)

Terrence and Rachel write her lines, so these are placeholders that show the
length and order, not final wording. On-screen words are sight words of 3 to 5
letters in a small speech bubble beside her; the voice says the rest.

**First visit** (plays once, about 30 s, a save flag `ellwynn_intro_seen` stops it repeating):

| # | Voice | Bubble |
|---|---|---|
| 1 | "Hi! I'm Ellwynn. I'm here to help you!" | Hi! |
| 2 | "To cross the lava, roll the dice and count the dots." | Roll |
| 3 | "Tap the stone with that number, then tap Go to hop." | Tap · Go |
| 4 | "Monsters will try to stop you. Pick the right number to beat them!" | Pick |
| 5 | "Open chests to find gems, and spend them in the Shop." | Gems · Shop |
| 6 | "If you miss, you go back to the start. Just try again!" | Try |
| 7 | "Tap Acorn to play. Tap me if you want to hear this again!" | Play |

While each line plays, the button it talks about glows (the Shop for line 5,
Acorn for line 7). Any tap on a button ends the intro and does what was tapped.

**Later visits:** one random line from a short set ("Welcome back!", "Ready to
roll?", "Let's go!"), and a tiny "?" bubble over her head as a reminder that
tapping her replays the explanation.

**Replay:** tapping her plays lines 2 to 7 (skipping the hello).

### In-play cues (from Terrence's list)

| Cue | Lines needed | Draft |
|---|---|---|
| Enemy beaten | 3 to 4 short ones | "Yay!", "You did it!", "Woo-hoo!", "Got it!" |
| Treasure opened | 3 to 4 | "Ooh, gems!", "Shiny!", "Nice find!" |
| Region boss beaten | 1 to 2 per boss | "You beat the Skeleton Dragon! You're amazing!" |
| Questions read aloud | 1 per question | "Which stone is safe?" and the fight and chest prompts |

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

**Steps:**

1. Terrence and Rachel finalise the wording (section 3).
2. One line per file, generated with 2 takes each. Terrence picks the take.
3. Trim silence, normalise loudness, and export as OGG for Godot (about 20 KB a line).
4. The script makes each line's mouth track (section 4).
5. Files go in `audio/voice/ellwynn/<cue>-<n>.ogg`, listed in one
   `content/ellwynn_lines.json` so cues pick from them.

**Cost estimate** (from ElevenLabs' published prices; I have not checked
Terrence's current plan):

| Batch | Characters (with 2 takes) | Credits | Dollars |
|---|---|---|---|
| Main menu intro, greetings, button reactions (about 17 lines) | about 1,400 | about 1,400 | |
| In-play cues and Lava Caves question lines (about 20 lines) | about 1,200 | about 1,200 | |
| Retakes margin | | about 1,000 | |
| **Total for this plan** | | **about 3,600** | **$5** (one month of the Starter plan, 30,000 credits), or **$0** if the current plan's credits cover it |

The Starter plan or higher is needed for the commercial licence when the game
ships on Steam and Xbox; the free plan does not include it. This is a small
part of the $100 to $200 voice budget for the whole series.

## 6. Build order (once the questions are answered)

1. Ellwynn node with idle bob, blink and mouth track playback (no new art, using placeholders for the extra frames).
2. Main menu spot, intro, replay, button reactions, save flag.
3. Voice queue and music ducking.
4. In-play cues: enemy "yay" pop-in, chest voice, boss congratulation, questions read aloud.
5. Generate audio and make mouth frames (after the spend is approved).

## 7. Questions for Terrence

1. **Wording:** do you and Rachel want to write the intro lines yourselves, or start from the draft in section 3?
2. **Main menu:** is the full body standing bottom left right, or would you rather have the 96 px bust in a corner there too?
3. **Pose:** are code moves (hop, lean, wave-like tilt) on the one approved image enough for now, or do you want a real pointing or waving pose? That would be new art, PixelLab first.
4. **Mouth frames:** shall I make the 2 or 3 mouth frames and the blink as free hand edits for you to check, or will you draw them in Aseprite?
5. **How often:** is "about 1 in 3 enemies" right for the quick "Yay!" pop-in, and should every chest get a voice line or only some?
6. **Boss win:** should she appear full body beside the hero when a region's boss is beaten, and is a longer line (about 5 s) okay there?
7. **Voice spend:** which ElevenLabs plan are you on now? Is about $5 (or the current credits) okay to generate the lines once the wording is final?
