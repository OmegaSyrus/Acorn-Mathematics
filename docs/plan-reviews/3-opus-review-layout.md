# Opus high review: sections 3 and 5 (stone layout, screen checklist)
Touch standard: plan's 15 mm floor. Device: look.gd:14 names 1340x800 (likely 8.7" Tab A9): 540 units ~4.46 in, 100 units ~0.83 in.
MUST FIX
1. 0.5x not grid-exact (look.gd:10-15, project.godot:37 nearest filter, no mipmaps). 1 unit = 1.48 device px, so at 0.5x 1 art px = 0.74 device px: rows dropped, shimmer on hop. Fonts alias in a 0.5 node (oversampling ignores node scale); Camera2D zoom same. Fix: drop "exact/integer zoom" claim; give Terrence the choice: half-size character art (look.gd rule) or LINEAR_WITH_MIPMAPS on the world at zoom. Draw all text (stone numbers, names, Go, GO! arrow) in an unscaled screen layer via one world_to_screen: (w - cam) * zoom + (0, 244).
2. Stones narrower than stated: 60 units = 12.6 mm on A9, not 0.6 in / 15 mm. Fix: step per level so offered stones fill x 150-810: ~82 screen units at Acorn 2 (17 mm), 66 at Acorn 3.
3. Drag vs tap (choice_widget.gd:76-96): widget picks on press and marks handled, scroll_screen never sees press; Go fires on press (82-86), swipe starting on Go commits an answer (wrong one sinks). Select on release breaks fresh-press rule (tray flick rolls while finger down, scroll_screen.gd:555-558; lifting over a stone would select). Pointer.local_pos gives world units so 24 threshold = 12 screen units. Fix: drag handling in ChoiceWidget; on drag levels stones and Go act on release; only a press the gate accepted while widget active can select, one touch index; threshold in viewport position.
4. Camera (scroll_screen.gd:203, 526-527, 588, 599): go_area set once, recompute each frame during drag; drag offset part of _cam_target() or lerp pulls back; world.position = (-roundf(cam_x*zoom), 244); lower clamp 0 must allow -110; strip starts at world 0 so 16:9 x 0-55 empty: tile from ~world -960; "hero never leaves screen" false (drag 570 at m=20 puts hero at x -420; Acorn 4 drag 90 -> 60 off 4:3): rewrite, add "back" cue.
5. Exit door tap area (scroll_screen.gd:350-353): exit_rect subtracts _cam_target() only; at zoom map door to screen then grow by INCH in screen units.
6. Edge arrow at (822,455) sits on stone 11's number; on 16:9 mid-screen. Put at visible right edge, y ~498 (between rock bottom 476 and progress bar 516).
7. Markers hit numbers (scroll_screen.gd:83-84): marker bottom world 381 incl bob, font-80 digits reach ~382, landmarks at 96 overlap ~17. MARKER_Y ~320 at zoom, outline 12 world units.
8. Monster names (685-689) font 11 in 18-unit box on screen: draw at 1/zoom.
9. Tray table collides: sign (draw_op size 44, line 837) ~50 wide but gaps 40/32; "=" font 72 ~51 wide, with 4 dice spans 642-694 over die 4 (646) and tray edge (690); Sapling 1 "=" at 610 and "12" at 650 overlap; Oak 1 die 3 ends 577 but "=" ~574; >=100 gems icon starts ~675 on 4:3 (873-875). Keep tray content x <= 670. Fitting layout (signs use size, "=" font 56):
   3 dice @72: centres 356,460,564; signs 408,512 (size 26); "=" 628
   4 dice @60: 343,429,515,601; signs 386,472,558 (size 22); "=" 652
   Sapling 1 dice @80: 356,476; sign 416; "=" 548; total 610
   Oak 1 dice @60: 340,426,512; signs 383,469; "=" 572; total 628
10. "Any die size fine" wrong: faces are 96 px art, skins built in 2 px chunks (dice_skins.gd:1-3,13-14) shown 1:1; only 48 exact; 72/64/60 alias. HALF const (die_view.gd:21). Pip tap radius 20 (die_view.gd:243) > pip spacing at 60 (13). Fix: build skin faces at target size, filter wood art, scale pip radius, pick nearest pip.
OPTIONAL
11. ui_scale must cover PAD, highlight grow/width/radius, Go tail sizes, corner radii (choice_widget.gd:17, 171-187).
12. hop_s also for _hop_along and door hop (345, 372); Beeper.count 14 steps (beeper.gd:33), hops 15-20 repeat top tone; camera lerp (rate 6) trails ~59 units at 0.17 s hops.
13. Drag decision by visible width: 16:10 shows stone 12 (870), 16:9 also 13; Acorn 4 needs drag only on 4:3.
14. Number box (line 675, 100 wide) -> ~140 for landmarks at 96; landmark "20" ~3.5 units from neighbours.
15. Section 5 checklist missing: drag, edge arrow, camera glide, controller scroll; ui_scale, select-on-release; exit_rect; world offset/rounding; strip tiling, cave roof; names, marker Y; HALF var, pip radius; >2 DieViews (scroll_screen.gd:162, 272-279 hard-code 2); tools/touch_check and stills at a zoomed level, drag test.
