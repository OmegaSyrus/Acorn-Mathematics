# Crystal Mines art

PixelLab (subscription), picked by Terrence on 2026-11-08. Prompts, seeds, raw takes and
mocks are in the project folder at sum-dungeon/art-crystal-mines/. Grid and look rules:
docs/art-style-guide.md.

Playable since 0.16.0 (docs/difficulty-plan.md milestone 5).
Characters are 1 art px = 1 unit; fight-bg, treasure-room and
cave-bg (320x180) draw at 3x like the Lava ones.

The crossing: the hero hops on stalagmites (stalagmite-1, stalagmite-wide, stalagmite-0
cycled), each with its top at the hop line and its foot off the bottom of the screen. A
wrong pick collapses its stalagmite (code: break into pieces and drop); right ones stay
stable. Ceiling pieces ceiling-0..3 (240x148, two stops wide) hang from the top of the
screen and scroll with the stalagmites, cycled in order. Strict side view, no perspective.
