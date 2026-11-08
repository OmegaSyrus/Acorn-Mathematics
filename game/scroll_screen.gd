## The lava crossing: a long row of rocks in the lava, crossed left to right.
## Each turn the child rolls two dice (add or subtract, answer 1 to 5) and taps
## the rock that many spaces ahead. Drives ScrollRun (all rules live there)
## and only animates what it returns. The world scrolls under a fixed HUD;
## both are drawn in the 960x540 design space.
extends Node2D

signal finished
signal rolled

const AreaFlow := preload("res://logic/path/area_flow.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const InputGate := preload("res://logic/core/input_gate.gd")
const SaveStore := preload("res://game/save_store.gd")
const DieView := preload("res://game/ui/die_view.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const Look := preload("res://game/ui/look.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const Monsters := preload("res://logic/fight/monsters.gd")
const GameMenu := preload("res://game/ui/game_menu.gd")
const WorldTheme := preload("res://game/ui/world_theme.gd")

const ART := "res://art/lava/"
const STRIP_SCALE := 3.0
## The crossing's world is 1920 art pixels wide at 3x in every world.
const WORLD_W := 5760.0
const SPACE0_X := 190.0
const STEP := 120.0
const WATER_Y := 452.0      # where the rocks meet the lava
const ROCK_WATERLINE := 64.0  # the waterline row inside a rock sprite
const FEET_Y := WATER_Y - 34.0
const HERO_SCREEN_X := 220.0
const CHEST_SCALE := 0.7
## The dice box: die, sign, die, "=", the answer, each die with its numeral
## under it. Its right edge stays left of the gems beside the menu button on
## a 4:3 tablet (2026-11-05). The picked answer goes after the "=", green when
## right and red when wrong (Terrence, 2026-11-07).
const TRAY := Rect2(292, 8, 404, 160)
## The small talk box left of the dice box: the question, and the count when
## a die's pips are tapped (back by Terrence's request 2026-11-05; tap it to
## hear the question again).
const BUBBLE := Rect2(124, 20, 168, 112)
const BUBBLE_FONT := 34
const BUBBLE_FONT_SMALL := 24
const DICE_Y := 64.0
const DICE_XS := [350.0, 494.0]
const OP_X := 422.0
const EQ_X := 568.0
const ANSWER_X := 640.0
const RIGHT_GREEN := Color(0.35, 0.95, 0.4)
const WRONG_RED := Color(1.0, 0.3, 0.25)
## A right answer: the dragon jumps for joy this many times (it was 2).
const HAPPY_JUMPS := 4
## The hero's hearts (3 lives), bottom left over the lava above the progress
## bar, clear of Ellwynn's pop-in under the talk box.
const HEARTS_AT := Vector2(150, 490)
const HEART_GAP := 36.0
const GEMS_Y := 26.0
const GEMS_FONT := 30
## The chest gems' animation, in seconds per gem (see _draw_chest_gems).
const GEM_HANG := 0.45
const GEM_SWOOP := 0.8
const GEM_LAND := 1.3
const GEM_STAGGER := 0.22
const BAR := Rect2(140, 516, 680, 10)
const DEBUG_CORNER := Rect2(120, 0, 90, 60)
const FLICK_PX := 24.0
const HOP_S := 0.34
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const PALE := Color(0.82, 0.9, 1.05)  # the worried dragon goes a little pale
## Monster art on the crossing comes from game/ui/world_theme.gd, drawn on
## the one character grid (Look.CHAR_PX). So do the backdrop, the stones and
## (in the Crystal Mines) the stalactite ceiling: the area file names its world.
## The hero is the robot dragon (2026-10-29: it replaced the slime). It has
## one sprite; the hop is squash, stretch and tilt done here, per frame
## name: [scale x, scale y, tilt in radians].
const HERO_POSE := {
	"idle-0": [1.0, 1.0, 0.0],
	"idle-1": [1.015, 0.985, 0.0],
	"blink": [1.0, 1.0, 0.0],
	"hop-squash": [1.16, 0.82, 0.0],
	"hop-stretch": [0.9, 1.12, -0.08],
	"hop-air": [1.0, 1.04, -0.14],
}
## The rocks ahead carry how far away they are (1 to 5), in the shields' look,
## so the answer is the number on the rock.
const STONE_NUM_Y := WATER_Y - 30.0
## Monster names under the monster on the crossing.
const NAME_Y := WATER_Y + 22.0
## Event rocks wear a marker (yellow treasure, red enemy) from the start; what
## is on them stays hidden until the dragon lands there. false hides the
## markers too, so every rock looks the same until it is reached.
const MARKERS_AHEAD := true
const MARKER_Y := WATER_Y - 104.0  # above the rock, clear of its number
const MARKER_SCALE := 1.5
## The way out on the far shore, this far past the last space.
const GOAL_DX := 200.0
## About an inch on the tablet, in design units. The game always shows 540
## units top to bottom, and a 10 inch tablet held sideways is about 5.4 inches
## tall, so 100 units is about 1 inch (a smaller 8 inch tablet makes it about
## 0.8 inch). The exit door's tap area is the door plus this all round.
const INCH := 100.0
const HEART_TEX := preload("res://art/ui/heart.png")
const HEART_EMPTY_TEX := preload("res://art/ui/heart-empty.png")

var run: ScrollRun
var save: Dictionary
var debug_on := false

var world: Node2D
var hud: Node2D
var overlay: Node2D
var choice: ChoiceWidget
var hud_choice: ChoiceWidget
var dice: Array = []
var tex := {}
var theme: Dictionary
var stone_tex: Array = []
var ceiling_tex: Array = []
var backdrop_tex: Texture2D  # a 320x180 tile at 3x, or null for the Lava strip

var cam_x := 0.0
## The level's view (docs/difficulty-plan.md 3.2): 1 at Lava 1, else half size,
## smoothed, with the stones spread to fill the screen (step per level).
var zoom := 1.0
var step := STEP
var hero_screen_x := HERO_SCREEN_X
var world_y := 0.0      # the world's screen y (244 at half size)
var rails := false      # Crystal Mines: only 1, 5, 10, 15 and the far shore numbered
## Drag to scroll (3.3): while the stones are offered, a drag moves the
## camera; it never picks. drag_off is in world units on top of the follow.
var drag_off := 0.0
var dragged := false    # a drag happened this crossing (the edge arrow fades)
var offering := false   # the stones are offered (choice active)
var offered := 0        # how many stones are offered
var stone_rects_world: Array = []
var hidden_place := -1  # the face-down die (Bog), -1 = none
var hidden_total := 0
var signs := ""
var hero_x := SPACE0_X
var hero_lift := 0.0
var hero_frame := "idle-0"
var hero_sink := 0.0
var worried := 0.0     # 0..1 the worried face while sinking
var stone_from := -1   # the space the rock numbers count from, -1 hides them
var sink_space := -1
var rock_sink := 0.0
var beaten := {}       # monster spaces beaten this attempt
var revealed := -1     # the event space the dragon is on, its contents shown
var reveal := 0.0      # 0..1 pop-in of the revealed chest or monster
var lid_open := false
var opening := -1      # chest space whose gems are flying
var gems_unshown := 0  # gems already banked in the save whose chest hasn't opened on screen yet
var gem_fly := 0.0     # seconds since the open chest's gems burst out
var gem_count := 0
var gems_landed := 0   # of the open chest's gems, how many reached the counter
var gem_pop := 0.0     # the counter's little jump when a gem lands, 0..1
var gem_icon := Vector2(800, 46)  # where the counter's gem is drawn (HUD), set by _draw_gems
var answer_shown := -1   # the picked answer after the "=", -1 = "?"
var answer_right := false
var hearts_unshown := 0  # hearts picked up on this walk that haven't flown to the row yet
var heart_fly := -1.0    # 0..1 a picked-up heart flying up to the row, -1 = none
var heart_from := Vector2.ZERO
var hearts_owed := 0     # hearts already lost in the run but still drawn full until they break
var heart_break := -1.0  # 0..1 the lost heart swelling and falling away, -1 = none
var op_sign := ""
var op_alpha := 0.0
var bubble := ""
var question := ""
var fade := 0.0
var cleared_banner := false
var tray_gate := InputGate.new()
var tray_waiting := false
var _tray_down := false
var _tray_down_at := Vector2.ZERO
var _corner_down_ms := -1
var _blink_at := 2.0
var _t := 0.0


func setup(scroll_run: ScrollRun, profile: Dictionary, show_debug: bool) -> void:
	run = scroll_run
	save = profile
	debug_on = show_debug


func _ready() -> void:
	for f in ["strip", "marker-treasure", "marker-enemy", "tile-wall-basalt", "chest-closed", "chest-open", "gem"]:
		tex[f] = load(ART + f + ".png")
	theme = WorldTheme.get_theme(str(run.area.get("world", WorldTheme.DEFAULT)))
	for p in theme["stones"]:
		stone_tex.append(load(p))
	for p in theme["ceiling"]:
		ceiling_tex.append(load(p))
	if theme["backdrop"] != "strip":
		backdrop_tex = load(theme["backdrop"])
	tex["hero"] = Look.hero_texture()  # the robot dragon or the store hero in use
	zoom = float(run.grade.get("zoom", 0.5 if run.is_level() else 1.0))
	rails = bool(run.grade.get("rails", false))
	if zoom < 1.0:
		var most := mini(int(run.grade["move"]["max_answer"]), 11)
		var screen_step := clampf(floorf(660.0 / most), 60.0, 110.0)
		step = screen_step / zoom
		hero_screen_x = 150.0
		world_y = 244.0
	world = Node2D.new()
	world.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	world.scale = Vector2(zoom, zoom)
	world.position.y = world_y
	if zoom < 1.0:
		# half size is smoothed (Terrence 2026-11-06)
		world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(world)
	world.draw.connect(_draw_world)
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	# select a stone, then tap Go (Terrence 2026-11-05)
	choice.confirm = true
	choice.selected.connect(_on_stone_selected)
	add_child(choice)
	hud = Node2D.new()
	hud.z_index = 2
	add_child(hud)
	hud.draw.connect(_draw_hud)
	for i in 4:
		var d := DieView.new()
		d.visible = false
		hud.add_child(d)
		d.pip_tapped.connect(_on_pip_tapped)
		dice.append(d)
	hud_choice = ChoiceWidget.new()
	hud.add_child(hud_choice)
	overlay = Node2D.new()
	overlay.z_index = 10
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	_place_hero(run.pos)
	if run.phase == ScrollRun.AWAIT_FIGHT:
		revealed = run.pos
		reveal = 1.0
	_loop()


# --- the turn loop ---------------------------------------------------------

func _loop() -> void:
	while true:
		if run.phase == ScrollRun.CLEARED:
			await _cleared()
			finished.emit()
			return
		if run.phase == ScrollRun.AWAIT_FIGHT:
			await _fight()
			_save_progress()
			continue
		stone_from = run.pos
		_ask("Roll!")
		await _wait_for_roll()
		# no small "Roll!" box while the dice tumble; it comes back with the question
		question = ""
		_say("")
		var p := run.roll()
		await _roll_dice(p)
		_ask("Which stone\nis safe?")
		stone_rects_world = []
		for d in p["choices"]:
			stone_rects_world.append(run.pos + d)
		offered = p["choices"].size()
		drag_off = 0.0
		# keep the Go button inside what a 4:3 tablet shows (x 120..840)
		choice.go_area = Rect2(132, 0, 690, 540)
		offering = true
		choice.present(_stone_rects(), 0)
		var pick: int = await choice.picked
		offering = false
		drag_off = 0.0
		var out := run.choose(pick)
		if hidden_place >= 0:
			# the face-down die turns over: its face is the stone picked right
			var hd: DieView = dice[hidden_place]
			hd.visible = true
			hd.show_still(int(p["answer"]))
			hd.show_numeral()
		# the answer goes after the "=": green when right, red when wrong
		answer_shown = int(p["choices"][pick])
		answer_right = out["right"]
		if out["right"]:
			await _happy(HAPPY_JUMPS)
			stone_from = -1
			await _play_walk(out)
		elif out["result"] == "miss":
			# 3 lives (Terrence 2026-11-08): hop to the wrong rock, start to
			# sink, hop back, lose a heart, and roll the same guess again
			stone_from = -1
			hearts_owed = 1
			await _hop_along(out["from"], out["to"])
			await _slip_back(out["to"], out["from"], int(p["answer"]))
		else:
			stone_from = -1
			await _hop_along(out["from"], out["to"])
			await _sink(out["to"], int(p["answer"]))
			await _restart()
		_hide_dice()
		_save_progress()


## A right answer's walk, rock by rock. Chests walked onto open on the way;
## the walk ends at the target, the goal, or a monster (fight, then the rest
## of the walk).
func _play_walk(w: Dictionary) -> void:
	var chest_gems := {}
	for c in w["chests"]:
		chest_gems[int(c["at"])] = int(c["gems"])
	# Bank the walk's gems and the run (chests now looted) in one write before
	# the walk plays, so leaving through the menu mid-walk can't open the same
	# chest twice on resume. The counter still climbs as each chest opens.
	if not chest_gems.is_empty():
		var total := int(w.get("gems", 0))
		SaveData.add_gems(save, total)
		gems_unshown += total
		_save_progress()
	var heart_spaces: Array = w.get("hearts", [])
	hearts_unshown = heart_spaces.size()
	revealed = -1
	var from: int = w["from"]
	for i in range(from + 1, int(w["to"]) + 1):
		revealed = -1
		await _hop(_space_x(i - 1), _space_x(i))
		Beeper.count(i - from)
		_say(str(i - from))
		if chest_gems.has(i):
			await _bounce()
			await _reveal(i)
			await _open_chest(i, chest_gems[i])
		if heart_spaces.has(i):
			await _bounce()
			await _take_heart(i)
	await _bounce()
	match w["result"]:
		"monster":
			await _reveal(int(w["to"]))
			_say("Fight!")
			await _wait(0.5)
			await _fight()
		"hop":
			_cheer("Yes!")
			await _wait(0.3)


func _wait_for_roll() -> void:
	tray_waiting = true
	tray_gate.present(Time.get_ticks_msec())
	await rolled
	tray_waiting = false
	tray_gate.close()


## Add: two wood dice. Subtract: the first die wood, the one taken away red.
## Once they land each shows its numeral underneath, then the sign and "=".
func _roll_dice(p: Dictionary) -> void:
	Beeper.roll()
	op_sign = "+" if p["op"] == "add" else "-"
	op_alpha = 0.0
	var n: int = p["dice"].size()
	signs = str(p.get("signs", "+" + ("-" if p["op"] == "sub" else "+")))
	hidden_place = int(p.get("hidden", -1))
	hidden_total = int(p.get("total", 0))
	var lay := tray_layout(n)
	for i in dice.size():
		var d: DieView = dice[i]
		d.visible = false
		if i >= n:
			continue
		d.slip = signs[i] == "-"
		d.position = Vector2(lay["xs"][i], DICE_Y)
		d.scale = Vector2(lay["scale"], lay["scale"])
		if i == hidden_place:
			continue  # face down: drawn as a "?" die by the HUD
		d.roll_to(p["dice"][i], 0.12 * i)
	var landed := false
	while not landed:
		landed = true
		for i in n:
			if i != hidden_place and not dice[i].face_on:
				landed = false
		await get_tree().process_frame
	for i in n:
		if i == hidden_place:
			continue
		dice[i].show_numeral()
		dice[i].countable = true
	await _tween_prop("op_alpha", 1.0, 0.2)


## Where the dice, signs, "=" and answer sit in the tray for n dice (plan 3.4,
## kept inside the tray, x 292 to 696). Two dice are today's layout.
func tray_layout(n: int) -> Dictionary:
	if n <= 2:
		return {"scale": 1.0, "xs": DICE_XS, "ops": [OP_X], "eq": EQ_X, "ans": ANSWER_X, "font": 72}
	var sc := 0.75 if n == 3 else 0.6
	var g := 144.0 * sc
	var x0 := 300.0 + 48.0 * sc + 2.0
	var xs := []
	var ops := []
	for i in n:
		xs.append(x0 + g * i)
		if i > 0:
			ops.append(x0 + g * (i - 0.5))
	var eq: float = xs[n - 1] + g * 0.51
	return {"scale": sc, "xs": xs, "ops": ops, "eq": eq, "ans": eq + 62.0 * sc + 6.0, "font": 56}


func _hide_dice() -> void:
	answer_shown = -1
	hidden_place = -1
	for d in dice:
		d.visible = false
		d.countable = false
	op_alpha = 0.0


func _save_progress() -> void:
	if run.phase == ScrollRun.CLEARED:
		SaveData.add_mark(save, run.area["id"], run.grade["id"])
		# through the door next: the miniboss (or what follows it), saved now
		# so closing the app at the door still leads on, not back to the start
		AreaFlow.enter(save, run.area, run.grade["id"], AreaFlow.next_stage(run.area, ""))
	else:
		save["run"] = run.to_save()
	SaveStore.write(save)


## A monster space: the fight screen covers the crossing until it ends. The
## fight draws from run.rng, so replays stay seeded. A loss starts the
## crossing again.
func _fight() -> void:
	_hide_dice()
	_ask("")
	var f := FightScreen.new()
	var fg: Dictionary = run.grade.get("fight", {"grade": run.grade["id"], "top": 0})
	f.setup(run.rng, int(fg["grade"]), run.current_monster(), false, false, debug_on, run.hearts)
	f.fight.set_top(int(fg["top"]))
	await _fade_to(1.0)
	add_child(f)
	await _fade_to(0.0)
	var won: bool = await f.done
	debug_on = f.debug_on
	await _fade_to(1.0)
	f.queue_free()
	var at := run.pos
	var out := run.resolve_fight(won, f.fight.hero_hearts)
	if out["restarted"]:
		await _restart()
	else:
		beaten[at] = true
		await _fade_to(0.0)
		await _happy()
		if out.has("walk"):
			_save_progress()
			await _play_walk(out["walk"])


## The crossing is done: a golden "GO!" arrow points at the door on the far
## shore, and tapping the door (or anywhere within about an inch of it) walks
## the dragon through it, on to the miniboss (main.gd leads on from there).
func _cleared() -> void:
	_save_progress()
	cleared_banner = true
	_cheer("Yes!")
	await _wait(0.5)
	_cheer("Yes!")
	question = ""
	hud_choice.show_highlight = false
	hud_choice.present([exit_rect()])
	await hud_choice.picked
	Beeper.good()
	await _hop(hero_x, _goal_x())
	await _fade_to(1.0)


## The door's tap area in screen (HUD) space, once the camera has settled.
func exit_rect() -> Rect2:
	var d := _door_rect()
	var a := _to_screen(d.position, _cam_target())
	var b := _to_screen(d.end, _cam_target())
	return Rect2(a, b - a).grow(INCH)


## The door in world space: the frame and the arch over it.
func _door_rect() -> Rect2:
	return Rect2(_goal_x() - 50, FEET_Y - 200, 100, 200)


func _goal_x() -> float:
	return _space_x(run.length()) + GOAL_DX


# --- animations ------------------------------------------------------------

## The dragon hops rock by rock, each hop counted, with a squash before the
## jump, a stretch on the way up and a small bounce on landing.
func _hop_along(from: int, to: int) -> void:
	revealed = -1
	for i in range(from + 1, to + 1):
		await _hop(_space_x(i - 1), _space_x(i))
		Beeper.count(i - from)
		_say(str(i - from))
	await _bounce()


func _hop(a: float, b: float) -> void:
	var arc := func(t: float) -> void:
		var e := clampf((t - 0.12) / 0.88, 0.0, 1.0)
		hero_x = lerpf(a, b, e)
		hero_lift = sin(e * PI) * 58.0
		if t < 0.12:
			hero_frame = "hop-squash"
		elif e < 0.35 or e > 0.8:
			hero_frame = "hop-stretch"
		else:
			hero_frame = "hop-air"
	await create_tween().tween_method(arc, 0.0, 1.0, HOP_S).finished
	hero_x = b
	hero_lift = 0.0


func _bounce() -> void:
	hero_frame = "hop-squash"
	await _wait(0.08)
	hero_frame = "hop-air"
	var up := func(t: float) -> void:
		hero_lift = sin(t * PI) * 12.0
	await create_tween().tween_method(up, 0.0, 1.0, 0.2).finished
	hero_lift = 0.0
	hero_frame = "hop-squash"
	await _wait(0.07)
	hero_frame = "idle-0"


## A right answer: the dragon jumps for joy on the spot (a few times on the
## crossing, Terrence 2026-11-07; twice after a fight).
func _happy(jumps := 2) -> void:
	Beeper.good()
	for k in jumps:
		hero_frame = "hop-squash"
		await _wait(0.06)
		hero_frame = "hop-stretch"
		var up := func(t: float) -> void:
			hero_lift = sin(t * PI) * 34.0
			hero_frame = "hop-air" if t > 0.25 and t < 0.75 else "hop-stretch"
		await create_tween().tween_method(up, 0.0, 1.0, 0.26).finished
		hero_lift = 0.0
	hero_frame = "hop-squash"
	await _wait(0.06)
	hero_frame = "idle-0"


## A wrong rock: it tips into the lava and the dragon sinks with a blorp.
## Ellwynn then says the right answer, cheerfully (Terrence 2026-11-07).
func _sink(space: int, answer := 0) -> void:
	sink_space = space
	Beeper.blorp()
	_say("Oops!")
	# a worried look first, then down it goes still looking worried
	await _tween_prop("worried", 1.0, 0.18)
	await _wait(0.35)
	if answer > 0:
		Ellwynn.say_answer(answer)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rock_sink", 1.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hero_sink", 1.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	await _wait(0.6)


## A wrong rock with hearts left: the rock dips and the dragon starts to sink,
## worried, then scrambles back to the rock it came from; a heart breaks.
func _slip_back(space: int, back_to: int, answer := 0) -> void:
	sink_space = space
	Beeper.blorp()
	_say("Oops!")
	await _tween_prop("worried", 1.0, 0.18)
	if answer > 0:
		Ellwynn.say_answer(answer)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rock_sink", 0.35, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "hero_sink", 0.3, 0.5).set_ease(Tween.EASE_IN)
	await tw.finished
	await _wait(0.25)
	# the jump back pulls it out of the lava
	create_tween().tween_property(self, "hero_sink", 0.0, HOP_S * 0.5)
	await _hop(_space_x(space), _space_x(back_to))
	create_tween().tween_property(self, "rock_sink", 0.0, 0.3)
	await _bounce()
	worried = 0.0
	sink_space = -1
	# the heart swells and falls away
	heart_break = 0.0
	Beeper.tone(220.0, 0.15)
	await _tween_prop("heart_break", 1.0, 0.9)
	heart_break = -1.0
	hearts_owed = 0
	_say("Roll again!")
	await _wait(0.4)


## The fail rule: back to the start of the crossing.
func _restart() -> void:
	await _fade_to(1.0)
	_hide_dice()
	beaten.clear()
	hearts_unshown = 0
	hearts_owed = 0
	revealed = -1
	sink_space = -1
	rock_sink = 0.0
	hero_sink = 0.0
	worried = 0.0
	_place_hero(0)
	_say("Again!")
	await _fade_to(0.0)
	await _wait(0.5)


## Landing on an event rock: its marker gives way to what was hidden there.
func _reveal(space: int) -> void:
	revealed = space
	reveal = 0.0
	lid_open = false
	Beeper.tone(330.0, 0.08)
	Beeper.tone(495.0, 0.12)
	await _tween_prop("reveal", 1.0, 0.35)
	await _wait(0.25)


## The chest's gems (2026-11-06, Terrence: "animate the gems a bit more"):
## each gem bursts out of the lid in turn, spinning, with sparkles, hangs and
## twinkles over the chest, then swoops up to the gem counter, which jumps and
## counts it as it lands.
func _open_chest(space: int, n: int) -> void:
	lid_open = true
	opening = space
	gem_count = n
	gem_fly = 0.0
	gems_landed = 0
	_cheer("+%d" % n)
	Beeper.tone(880.0, 0.08, -8.0)
	Ellwynn.chest_opened()
	var total := GEM_LAND + GEM_STAGGER * (n - 1) + 0.15
	while gem_fly < total:
		await get_tree().process_frame
		gem_fly += get_process_delta_time()
		var landed := 0
		for k in n:
			if gem_fly >= GEM_STAGGER * k + GEM_LAND:
				landed += 1
		while gems_landed < landed:
			gems_landed += 1
			gems_unshown = maxi(gems_unshown - 1, 0)
			gem_pop = 1.0
			Beeper.tone(1046.0 * pow(1.12, gems_landed - 1), 0.09, -10.0)
	opening = -1


## A heart stone: the heart over it pops, then flies up to the hearts row
## under the talk box, which gains it as it lands.
func _take_heart(space: int) -> void:
	revealed = space
	heart_from = _to_screen(Vector2(_space_x(space), MARKER_Y))
	heart_fly = 0.0
	_cheer("+1")
	Beeper.tone(660.0, 0.08)
	Beeper.tone(990.0, 0.14)
	await _tween_prop("heart_fly", 1.0, 0.9)
	heart_fly = -1.0
	hearts_unshown = maxi(hearts_unshown - 1, 0)
	Beeper.tone(1320.0, 0.1, -8.0)
	await _wait(0.2)


func _place_hero(space: int) -> void:
	hero_x = _space_x(space)
	hero_lift = 0.0
	hero_frame = "idle-0"
	cam_x = _cam_target()


func _fade_to(alpha: float) -> void:
	await _tween_prop("fade", alpha, 0.25)


func _tween_prop(prop: String, to: float, dur: float) -> void:
	await create_tween().tween_property(self, prop, to, dur).finished


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# --- talk ------------------------------------------------------------------

func _ask(q: String) -> void:
	question = q
	_say(q)


func _say(text: String) -> void:
	bubble = text


func _cheer(text: String) -> void:
	_say(text)
	Beeper.good()


func _on_stone_selected(_i: int) -> void:
	Beeper.tone(523.0, 0.07)


func _on_pip_tapped(count: int) -> void:
	Beeper.count(count)
	_say(str(count))


# --- input -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	cam_x = lerpf(cam_x, _cam_target(), minf(1.0, delta * 6.0))
	gem_pop = maxf(0.0, gem_pop - delta * 4.0)
	world.position.x = -roundf(cam_x * zoom)
	if offering and choice.active:
		choice.rects = _stone_rects()
	if hero_frame.begins_with("idle") or hero_frame == "blink":
		hero_frame = "idle-1" if fmod(_t, 1.2) > 0.6 else "idle-0"
		if _t > _blink_at:
			hero_frame = "blink"
			if _t > _blink_at + 0.15:
				_blink_at = _t + 2.5 + fmod(_t * 7.3, 2.0)
	if tray_waiting and Input.is_action_just_pressed("pick") and tray_gate.accepts(Time.get_ticks_msec()):
		rolled.emit()
	if Input.is_action_just_pressed("repeat") and question != "":
		_say(question)
	if Input.is_action_just_pressed("debug"):
		debug_on = not debug_on
	if _corner_down_ms >= 0 and Time.get_ticks_msec() - _corner_down_ms > 1500:
		_corner_down_ms = -1
		debug_on = not debug_on
	world.queue_redraw()
	hud.queue_redraw()
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var press := Pointer.is_press(event)
	var release := Pointer.is_release(event)
	var drag := Pointer.is_drag(event)
	if not (press or release or drag):
		return
	var pos := Pointer.local_pos(self, event)
	if drag and offering and _can_drag():
		var rel: Vector2 = event.relative if "relative" in event else Vector2.ZERO
		drag_off = clampf(drag_off - rel.x / zoom, _drag_min(), _drag_max())
		cam_x = _cam_target()
		if absf(rel.x) > 0.0:
			dragged = true
		return
	if drag:
		if _tray_down and pos.distance_to(_tray_down_at) >= FLICK_PX:
			_tray_down = false
			rolled.emit()
		return
	if press:
		if tray_waiting and TRAY.has_point(pos) and tray_gate.accepts(Time.get_ticks_msec()):
			_tray_down = true
			_tray_down_at = pos
		elif BUBBLE.has_point(pos) and question != "" and not tray_waiting:
			_say(question)
		elif DEBUG_CORNER.has_point(pos):
			_corner_down_ms = Time.get_ticks_msec()
	else:
		if _tray_down and tray_waiting:
			_tray_down = false
			rolled.emit()
		_tray_down = false
		_corner_down_ms = -1


# --- layout ----------------------------------------------------------------

func _space_x(i: int) -> float:
	return SPACE0_X + step * i


## Long crossings run past the 5760 strip: the backdrop repeats.
func _world_w() -> float:
	return maxf(WORLD_W, _space_x(run.length()) + GOAL_DX + 960.0 / zoom + 400.0)


## Keeps the dragon near the left so the next rocks are on screen; a drag
## while the stones are offered moves on from there.
func _cam_target() -> float:
	var lo := 0.0 if zoom >= 1.0 else SPACE0_X - hero_screen_x / zoom
	return clampf(hero_x - hero_screen_x / zoom + drag_off, lo, _world_w() - 960.0 / zoom)


## World to screen, through the camera (and the half-size view).
func _to_screen(w: Vector2, cx := INF) -> Vector2:
	if cx == INF:
		cx = roundf(cam_x * zoom) / zoom
	return Vector2((w.x - cx) * zoom, w.y * zoom + world_y)


func _rock_rect(i: int) -> Rect2:
	return Rect2(_space_x(i) - 58, WATER_Y - 62, 116, 80)


## The offered stones' tap areas on screen: at half size a step wide and
## 86 tall, so text and touch stay full size.
func _stone_rects() -> Array:
	var out := []
	for i in stone_rects_world:
		var r := _rock_rect(i)
		if zoom >= 1.0:
			r.position.x -= roundf(cam_x)
			out.append(r)
			continue
		var c := _to_screen(r.get_center())
		var w := minf(step * zoom, 116.0)
		out.append(Rect2(c - Vector2(w / 2.0, 43.0), Vector2(w, 86.0)))
	return out


## The last offered stone runs past the visible right edge: drag to see it.
func _can_drag() -> bool:
	return offered > 0 and _space_x(run.pos + offered) > _drag_min_edge()


func _drag_min_edge() -> float:
	return hero_x - hero_screen_x / zoom + 800.0 / zoom


func _drag_min() -> float:
	return 0.0


## Far enough right that the last offered stone sits at screen x 780.
func _drag_max() -> float:
	return maxf(0.0, _space_x(run.pos + offered) - 780.0 / zoom - (hero_x - hero_screen_x / zoom))


# --- drawing ---------------------------------------------------------------

func _draw_world() -> void:
	if zoom < 1.0:
		# above the strip at half size: dark cave rock fading into it
		var roof := Rect2(-2000, -world_y / zoom - 20, _world_w() + 4000, world_y / zoom + 20)
		var lt: Color = theme["ledge_tint"]
		world.draw_texture_rect(tex["tile-wall-basalt"], roof, true, Color(lt.r * 0.42, lt.g * 0.42, lt.b * 0.42))
		# a soft dark edge where the roof meets the backdrop
		for k in 6:
			world.draw_rect(Rect2(roof.position.x, -24.0 + k * 4.0, roof.size.x, 4.0), Color(0, 0, 0, 0.5 - k * 0.08))
		world.draw_rect(Rect2(-2000, 540, _world_w() + 4000, 200), Color(0.06, 0.04, 0.07))
	if backdrop_tex == null:
		var strip: Texture2D = tex["strip"]
		var sw := strip.get_width() * STRIP_SCALE
		var k := -1 if zoom < 1.0 else 0
		while k * sw < _world_w():
			# every other copy mirrored so the seam matches
			if k % 2 == 0:
				world.draw_texture_rect(strip, Rect2(Vector2(k * sw, 0), strip.get_size() * STRIP_SCALE), false)
			else:
				world.draw_set_transform(Vector2((k + 1) * sw, 0), 0.0, Vector2(-1, 1))
				world.draw_texture_rect(strip, Rect2(Vector2.ZERO, strip.get_size() * STRIP_SCALE), false)
				world.draw_set_transform(Vector2.ZERO)
			k += 1
	else:
		# a seamless 320x180 backdrop, tiled along the crossing at 3x
		world.draw_set_transform(Vector2.ZERO, 0.0, Vector2(STRIP_SCALE, STRIP_SCALE))
		world.draw_texture_rect(backdrop_tex, Rect2(-1920 / STRIP_SCALE, 0, (_world_w() + 1920) / STRIP_SCALE, 180), true)
		world.draw_set_transform(Vector2.ZERO)
	if theme["glow"]:
		# a little shimmer on the lava
		var glow := 0.05 + 0.05 * sin(_t * 2.2)
		world.draw_rect(Rect2(0, 380, _world_w(), 160), Color(1.0, 0.7, 0.2, glow))
	# stalactites hanging from the ceiling, scrolling with the stones
	if not ceiling_tex.is_empty():
		var step: float = theme["ceiling_step"]
		var k := 0
		var x := SPACE0_X - step / 2.0
		while x < _world_w():
			world.draw_texture(ceiling_tex[k % ceiling_tex.size()], Vector2(x, 0))
			x += step
			k += 1
	# the ledges at the start and the far shore
	var wall: Texture2D = tex["tile-wall-basalt"]
	var start_ledge := Rect2(-40 - (1200.0 if zoom < 1.0 else 0.0), FEET_Y, SPACE0_X + 56 + (1200.0 if zoom < 1.0 else 0.0), 200)
	var end_ledge := Rect2(_space_x(run.length()) - 56, FEET_Y, 1200, 200)
	for r in [start_ledge, end_ledge]:
		world.draw_texture_rect(wall, r, true, theme["ledge_tint"])
		world.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(0.45, 0.3, 0.5))
	_draw_goal(Vector2(_goal_x(), FEET_Y))
	# rocks
	for i in range(1, run.length()):
		var rock: Texture2D = stone_tex[i % stone_tex.size()]
		var p := Vector2(_space_x(i) - rock.get_width() / 2.0, WATER_Y - float(theme["waterline"]))
		if theme["stone_top"]:
			p.y = FEET_Y - 4.0  # a stalagmite: the hero stands on its top
		if i == sink_space:
			var depth: float = theme["sink_depth"]
			if theme["stone_top"]:
				# the stalagmite cracks and collapses into the dark
				p.x += sin(_t * 60.0) * 3.0 * minf(1.0, rock_sink * 4.0)
				p.y += rock_sink * depth
				_draw_clipped(rock, p, 560.0, 1.0 - rock_sink * 0.3)
			else:
				p.y += rock_sink * depth
				_draw_clipped(rock, p, WATER_Y + 12.0, 1.0 - rock_sink * 0.5)
		else:
			world.draw_texture(rock, p)
	# markers on event rocks not reached yet
	for i in range(1, run.length()):
		var kind := _event_at(i)
		if kind == "" or i == revealed or not MARKERS_AHEAD or i == sink_space:
			continue
		var bob := sin(_t * 2.5 + i * 0.7) * 3.0
		if kind == "heart":
			# a heart floats over a heart stone (2x, whole pixels), gently pulsing
			var hs := HEART_TEX.get_size() * (2.0 if fmod(_t, 1.2) > 0.15 else 2.25)
			world.draw_texture_rect(HEART_TEX, Rect2(Vector2(_space_x(i), MARKER_Y + bob) - hs / 2.0, hs), false)
			continue
		var m: Texture2D = tex["marker-treasure" if kind == "chest" else "marker-enemy"]
		var ms := m.get_size() * MARKER_SCALE
		world.draw_texture_rect(m, Rect2(Vector2(_space_x(i), MARKER_Y + bob) - ms / 2.0, ms), false)
	_draw_stone_numbers()
	# the dragon
	_draw_hero()
	# the monster on the rock just reached, beside the dragon and facing it
	if revealed >= 0 and _event_at(revealed) == "monster":
		var s := run.space_at(revealed)
		var t: Texture2D = _monster_tex(str(s["monster"]))
		var size: Vector2 = t.get_size() * Look.CHAR_PX * _pop()
		var breathe := sin(_t * 2.0) * 2.0
		var c := Vector2(_space_x(revealed) + 84, FEET_Y + 6)
		# the art faces right; a negative width mirrors it to face the dragon
		world.draw_texture_rect(t, Rect2(c + Vector2(size.x / 2, -size.y - breathe), Vector2(-size.x, size.y + breathe)), false)
		# its name underneath, in a fiery box
		# (the mirrored rect lands one width right of c, so its middle is c.x + size.x)
		_draw_name(Monsters.name_of(str(s["monster"])), Vector2(c.x + size.x, NAME_Y), reveal)
	# the chest on the rock just reached, in front of the dragon so it stays in view
	if revealed >= 0 and run.space_at(revealed).get("type") == "chest":
		var t: Texture2D = tex["chest-open" if lid_open else "chest-closed"]
		var size := t.get_size() * CHEST_SCALE * _pop()
		var c := Vector2(_space_x(revealed) + 46, FEET_Y + 6)
		world.draw_texture_rect(t, Rect2(c - Vector2(size.x / 2, size.y), size), false)
	# (the gems flying out of an opened chest are drawn on the HUD, _draw_chest_gems)


## The numbers on the rocks ahead: how many spaces away each one is, drawn
## like the numerals on the fight shields (dark with a light outline).
func _draw_stone_numbers() -> void:
	if stone_from < 0:
		return
	var font := ThemeDB.fallback_font
	var m := mini(int(run.grade["move"]["max_answer"]), run.length() - stone_from)
	# at half size the numbers stay big on screen (font 40, landmarks 48)
	var k := 1.0 if zoom >= 1.0 else 40.0 / 48.0 / zoom
	for d in range(1, m + 1):
		var i := stone_from + d
		if i == sink_space:
			continue
		var shore := i >= run.length()
		var landmark := zoom < 1.0 and d % 5 == 0
		if rails and not (d == 1 or landmark or shore):
			continue  # a blank rail stop: count on from 1, 5, 10, 15
		var c := Vector2(_space_x(i), STONE_NUM_Y)
		if shore:
			c.y = FEET_Y + 40.0  # the far shore: on the ledge face
		var fs := int(48.0 * k * (1.2 if landmark else 1.0))
		var w := 100.0 * k * 1.4
		var at := c + Vector2(-w / 2.0, fs * 0.36)
		var ink := Color(0.08, 0.06, 0.05)
		var rim := Color(1, 0.95, 0.85)
		if landmark:
			world.draw_arc(Vector2(c.x, WATER_Y - 14.0), 46.0 * k, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.8), 5.0 * k)
			ink = Color(0.35, 0.22, 0.0)
			rim = Color(1.0, 0.85, 0.3)
		world.draw_string_outline(font, at, str(d), HORIZONTAL_ALIGNMENT_CENTER, w, fs, int(6 * k), rim)
		world.draw_string(font, at, str(d), HORIZONTAL_ALIGNMENT_CENTER, w, fs, ink)


func _draw_name(text: String, center: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var k := 1.0 / zoom  # the same size on screen at half size
	var fs := int(22 * k)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 32.0 * k
	var box := Rect2(center.x - w / 2.0, center.y, w, 36 * k)
	RoundBox.fire(world, box, _t, 12.0 * k)
	world.draw_string_outline(font, box.position + Vector2(0, 26 * k), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, int(6 * k), DARK)
	world.draw_string(font, box.position + Vector2(0, 26 * k), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, INK)


## "chest", "monster" or "heart" while that space still holds something, else "".
## An opened chest is empty for good; a beaten monster is gone this attempt.
func _event_at(i: int) -> String:
	var s := run.space_at(i)
	match s.get("type", ""):
		"chest":
			return "" if run.is_looted(i) and i != revealed else "chest"
		"monster":
			return "" if beaten.has(i) else "monster"
		"heart":
			return "" if run.is_heart_taken(i) else "heart"
	return ""


## The pop-in scale of a revealed chest or monster, with a little overshoot.
func _pop() -> float:
	return lerpf(0.3, 1.0, reveal) + 0.15 * sin(reveal * PI)


func _draw_hero() -> void:
	var t: Texture2D = tex["hero"]
	var falls: bool = theme["stone_top"]  # no water: the dragon drops with the stalagmite
	var feet := Vector2(hero_x, FEET_Y - hero_lift + hero_sink * (theme["sink_depth"] if falls else 120.0))
	var pos := feet - Vector2(t.get_width() / 2.0, t.get_height())
	var line := 600.0 if falls else WATER_Y - 4.0
	if hero_sink > 0.0:
		_draw_clipped(t, pos, line, 1.0, PALE)
		_draw_worried(pos, line)
		# bubbles where it went under
		for k in (0 if falls else 4):
			var ph := fmod(_t * 1.7 + k * 0.27, 1.0)
			world.draw_circle(Vector2(hero_x - 30 + k * 20, WATER_Y - 6 - ph * 22.0), 5.0 * (1.0 - ph) + 1.0,
					Color(theme.get("bubble", Color(1.0, 0.85, 0.4)), (1.0 - ph) * minf(1.0, hero_sink * 3.0)))
	else:
		world.draw_circle(Vector2(hero_x, FEET_Y + 2), 30.0 - hero_lift * 0.25, Color(0, 0, 0, 0.25))
		# squash, stretch and tilt about the feet
		var pose: Array = HERO_POSE.get(hero_frame, HERO_POSE["idle-0"])
		world.draw_set_transform(feet, pose[2], Vector2(pose[0], pose[1]))
		var shake := Vector2(sin(_t * 40.0) * 2.0 * worried, 0)
		world.draw_texture(t, Vector2(-t.get_width() / 2.0, -t.get_height()) + shake, Color.WHITE.lerp(PALE, worried))
		world.draw_set_transform(Vector2.ZERO)
		if worried > 0.0:
			_draw_worried(pos + shake, INF)


## The worried face, drawn over the sprite in its own pixels (93 x 115, the
## big eye at about x 33..68, y 28..50): a brow raised toward the snout and
## sweat drops, with a tremble and a pale tint. Only what is above line_y shows.
func _draw_worried(top_left: Vector2, line_y: float) -> void:
	var a := worried
	var ink := Color(0.12, 0.1, 0.16, a)
	# the brow, just over the eye: low at the outer end, steeply up toward the
	# snout (worried, not cross). Only the dragon's eye is known; other store
	# heroes just sweat.
	for k in (8 if Look.is_default_hero() else 0):
		var p := top_left + Vector2(31 + k * 3.5, 27 - k * 1.9)
		if p.y < line_y:
			world.draw_rect(Rect2(p.round(), Vector2(5, 5)), ink)
	# two sweat drops by the head, sliding down
	for j in 2:
		var drop := top_left + Vector2(18 - j * 10, 8 + j * 14 + fmod(_t * 12.0 + j * 4.0, 10.0))
		if drop.y + 12 >= line_y:
			continue
		var blue := Color(0.6, 0.88, 1.0, a)
		world.draw_circle(drop + Vector2(0, 7), 6.0, blue)
		world.draw_colored_polygon(PackedVector2Array([drop + Vector2(-5.5, 6), drop + Vector2(0, -5), drop + Vector2(5.5, 6)]), blue)
		world.draw_rect(Rect2(drop + Vector2(-3, 5), Vector2(2, 2)), Color(1, 1, 1, a))


## Draws only the part of a sprite above the lava line, so it sinks into it.
func _draw_clipped(t: Texture2D, pos: Vector2, line_y: float, alpha: float, tint := Color.WHITE) -> void:
	var h := clampf(line_y - pos.y, 0.0, t.get_height())
	if h <= 0.0:
		return
	world.draw_texture_rect_region(t, Rect2(pos, Vector2(t.get_width(), h)), Rect2(0, 0, t.get_width(), h),
			Color(tint, alpha))


func _draw_goal(base: Vector2) -> void:
	# a glowing way out on the far shore
	world.draw_rect(Rect2(base + Vector2(-50, -150), Vector2(100, 150)), Color(0.12, 0.07, 0.12))
	world.draw_arc(base + Vector2(0, -150), 50.0, PI, TAU, 24, Color(0.12, 0.07, 0.12), 20.0)
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	world.draw_rect(Rect2(base + Vector2(-38, -140), Vector2(76, 140)), Color(1.0, 0.85, 0.4, 0.35 * pulse))
	world.draw_circle(base + Vector2(0, -170), 14.0, Color(1.0, 0.85, 0.3, pulse))
	if cleared_banner:
		_draw_go_arrow(base + Vector2(0, -212 + 8.0 * sin(_t * 4.0)))


## A golden arrow pointing down at the door, with "GO!" on it. tip is the
## arrow's point.
func _draw_go_arrow(tip: Vector2) -> void:
	var gold := Color(1.0, 0.8, 0.22)
	var light := Color(1.0, 0.94, 0.55)
	var edge := Color(0.42, 0.24, 0.05)
	var pts := PackedVector2Array([
		tip + Vector2(-58, -70), tip + Vector2(-82, -70), tip,
		tip + Vector2(82, -70), tip + Vector2(58, -70),
		tip + Vector2(58, -150), tip + Vector2(-58, -150),
	])
	# a dark edge, the gold body, then a shine down the left side
	world.draw_colored_polygon(_grow_poly(pts, 6.0), edge)
	world.draw_colored_polygon(pts, gold)
	world.draw_colored_polygon(PackedVector2Array([tip + Vector2(-50, -142), tip + Vector2(-34, -142),
			tip + Vector2(-34, -78), tip + Vector2(-50, -78)]), Color(light, 0.8))
	var font := ThemeDB.fallback_font
	var at := tip + Vector2(-58, -92)
	world.draw_string_outline(font, at, "GO!", HORIZONTAL_ALIGNMENT_CENTER, 116, 44, 6, light)
	world.draw_string(font, at, "GO!", HORIZONTAL_ALIGNMENT_CENTER, 116, 44, edge)


## The polygon pushed out from its middle by about px (for a simple outline).
func _grow_poly(pts: PackedVector2Array, px: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(pts, px)
	return grown[0] if grown.size() > 0 else pts


## Short words sit on one big line; a longer question wraps onto two.
## Hidden while the dice wait to be rolled: the big dice box with "Roll" is
## the only box until then (Terrence, 2026-11-07).
func _draw_bubble(font: Font) -> void:
	if bubble == "" or tray_waiting:
		return
	RoundBox.fire(hud, BUBBLE, _t, 18.0)
	var w := BUBBLE.size.x - 8.0
	if font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT).x <= w:
		var at := BUBBLE.position + Vector2(4, BUBBLE.size.y / 2.0 + BUBBLE_FONT * 0.36)
		hud.draw_string_outline(font, at, bubble, HORIZONTAL_ALIGNMENT_CENTER, w, BUBBLE_FONT, 7, DARK)
		hud.draw_string(font, at, bubble, HORIZONTAL_ALIGNMENT_CENTER, w, BUBBLE_FONT, INK)
		return
	var lines := font.get_multiline_string_size(bubble, HORIZONTAL_ALIGNMENT_CENTER, w, BUBBLE_FONT_SMALL).y
	var top := BUBBLE.position.y + (BUBBLE.size.y - lines) / 2.0 + font.get_ascent(BUBBLE_FONT_SMALL)
	var at := Vector2(BUBBLE.position.x + 4, top)
	hud.draw_multiline_string_outline(font, at, bubble, HORIZONTAL_ALIGNMENT_CENTER, w, BUBBLE_FONT_SMALL, 3, 7, DARK)
	hud.draw_multiline_string(font, at, bubble, HORIZONTAL_ALIGNMENT_CENTER, w, BUBBLE_FONT_SMALL, 3, INK)


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	if cleared_banner:
		_draw_cleared(font)
		return
	# dice tray
	RoundBox.fire(hud, TRAY, _t, 18.0)
	if tray_waiting:
		var a := 0.5 + 0.5 * sin(_t * 5.0)
		RoundBox.frame(hud, TRAY.grow(3), Color(1.0, 0.92, 0.3, a), 4.0, 20.0)
		hud.draw_string_outline(font, TRAY.position + Vector2(0, 90), "Roll", HORIZONTAL_ALIGNMENT_CENTER, TRAY.size.x, 40, 8, DARK)
		hud.draw_string(font, TRAY.position + Vector2(0, 90), "Roll", HORIZONTAL_ALIGNMENT_CENTER, TRAY.size.x, 40, INK)
	if hidden_place >= 0 and not dice[hidden_place].visible and signs.length() > hidden_place:
		_draw_hidden_die(font)
	if op_alpha > 0.0:
		# plus or minus between the dice, coloured and gently pulsing, then "="
		var lay := tray_layout(signs.length())
		var fs: int = lay["font"]
		for k in lay["ops"].size():
			var sg := "+" if signs[k + 1] == "+" else "-"
			DiceDraw.draw_op(hud, Vector2(lay["ops"][k], DICE_Y), sg, 44.0 * lay["scale"], _t, op_alpha)
		var eq := Color(INK, op_alpha)
		var eq_x: float = lay["eq"]
		hud.draw_string_outline(font, Vector2(eq_x - 40, DICE_Y + fs * 0.3), "=", HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 8, Color(DARK, op_alpha))
		hud.draw_string(font, Vector2(eq_x - 40, DICE_Y + fs * 0.3), "=", HORIZONTAL_ALIGNMENT_CENTER, 80, fs, eq)
		# then the answer: a faint "?" until a stone is picked; with a
		# face-down die the total is known and the die is the question
		var ans := "?" if answer_shown < 0 else str(answer_shown)
		var col := Color(INK, op_alpha * 0.45)
		if hidden_place >= 0:
			ans = str(hidden_total)
			col = eq
		elif answer_shown >= 0:
			col = RIGHT_GREEN if answer_right else WRONG_RED
		var ans_x: float = lay["ans"]
		hud.draw_string_outline(font, Vector2(ans_x - 40, DICE_Y + fs * 0.36), ans, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 8,
				Color(DARK, op_alpha))
		hud.draw_string(font, Vector2(ans_x - 40, DICE_Y + fs * 0.36), ans, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
	_draw_bubble(font)
	_draw_drag_arrows()
	_draw_hearts()
	_draw_gems(font)
	_draw_chest_gems()
	# progress along the crossing: one tick per space
	var n := run.length()
	RoundBox.fill(hud, BAR.grow(3), Color(0.1, 0.05, 0.1, 0.8), 8.0)
	if run.pos > 0:
		RoundBox.fill(hud, Rect2(BAR.position, Vector2(BAR.size.x * run.pos / n, BAR.size.y)), Color(0.4, 0.85, 0.65), 5.0)
	for i in range(1, n + 1):
		var x := BAR.position.x + BAR.size.x * i / n
		var s := run.space_at(i)
		if s.get("type") == "chest" and not run.is_looted(i):
			hud.draw_circle(Vector2(x, BAR.get_center().y), 5.0, Color(1.0, 0.8, 0.2))
		elif s.get("type") == "monster" and not beaten.has(i):
			hud.draw_circle(Vector2(x, BAR.get_center().y), 5.0, Color(0.9, 0.2, 0.2))
		elif s.get("type") == "heart" and not run.is_heart_taken(i):
			hud.draw_circle(Vector2(x, BAR.get_center().y), 5.0, Color(1.0, 0.45, 0.6))


## The face-down die (Bog, plan 3.4): a die-sized tile with a "?", red when
## it is a take-away die; it turns over once the right stone is picked.
func _draw_hidden_die(font: Font) -> void:
	var lay := tray_layout(signs.length())
	var sz: float = 96.0 * lay["scale"]
	var c := Vector2(lay["xs"][hidden_place], DICE_Y)
	var r := Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz))
	var red := signs[hidden_place] == "-"
	var wob := sin(_t * 3.0) * 2.0
	r.position.y += wob
	RoundBox.fill(hud, r.grow(4), DARK, sz * 0.2)
	RoundBox.fill(hud, r, Color(0.75, 0.2, 0.18) if red else Color(0.55, 0.38, 0.22), sz * 0.18)
	RoundBox.fill(hud, r.grow(-sz * 0.1), Color(0.62, 0.25, 0.22) if red else Color(0.64, 0.46, 0.28), sz * 0.14)
	var fs := int(sz * 0.7)
	var at := Vector2(r.position.x, r.get_center().y + fs * 0.36)
	hud.draw_string_outline(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 8, DARK)
	hud.draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, INK)


## While stones are off to the right: a soft chevron at the right edge; after
## a drag, a back chevron at the left while the hero is off screen.
func _draw_drag_arrows() -> void:
	if not offering or not _can_drag():
		return
	var a := 0.55 + 0.35 * sin(_t * 4.0)
	var last_x := _to_screen(Vector2(_space_x(run.pos + offered), 0)).x
	if last_x > 812.0:
		_chevron(Vector2(822, 498), 1.0, a * (0.5 if dragged else 1.0))
	if _to_screen(Vector2(hero_x, 0)).x < 128.0:
		_chevron(Vector2(138, 498), -1.0, a)


func _chevron(c: Vector2, dir: float, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-10 * dir, -18), c + Vector2(10 * dir, 0), c + Vector2(-10 * dir, 18)])
	hud.draw_polyline(pts, Color(DARK, a), 12.0)
	hud.draw_polyline(pts, Color(1.0, 0.92, 0.3, a), 6.0)


## The hero's hearts under the talk box, and a picked-up heart flying to them.
func _draw_hearts() -> void:
	var have := run.hearts - hearts_unshown + hearts_owed
	var slots := maxi(ScrollRun.HERO_HEARTS, run.hearts + hearts_owed)
	for i in slots:
		var c := HEARTS_AT + Vector2(HEART_GAP * i, 0)
		var full := i < have
		if heart_break >= 0.0 and i == have - 1:
			full = false  # drawn breaking below
		hud.draw_texture(HEART_TEX if full else HEART_EMPTY_TEX, c - Vector2(16, 16))
	if heart_break >= 0.0 and have > 0:
		var c := HEARTS_AT + Vector2(HEART_GAP * (have - 1), 0)
		var q := heart_break
		var k := 2.0 if q < 0.15 else 3.0
		var shake := roundf(sin(q * 90.0) * 3.0) if q < 0.5 else 0.0
		var drop := 0.0 if q < 0.5 else roundf((q - 0.5) * (q - 0.5) * 480.0)
		var a := 1.0 if q < 0.5 else 1.0 - (q - 0.5) * 2.0
		var hs := HEART_TEX.get_size() * k
		var at := Vector2(c.x + shake, maxf(c.y, hs.y / 2.0 + 4.0) + drop)
		hud.draw_texture_rect(HEART_TEX, Rect2(at - hs / 2.0, hs), false, Color(1, 1, 1, a))
	if heart_fly >= 0.0:
		var to := HEARTS_AT + Vector2(HEART_GAP * have, 0)
		var q := heart_fly
		var p := heart_from.lerp(to, q * q) + Vector2(0, -sin(q * PI) * 90.0)
		var k := 2.0 if q < 0.7 else 1.0
		var hs := HEART_TEX.get_size() * k
		hud.draw_texture_rect(HEART_TEX, Rect2(p.round() - hs / 2.0, hs), false)


## The crossing done: the area's name in a box to the right of the door,
## and the gems. The door itself is the way out.
func _draw_cleared(font: Font) -> void:
	var box := Rect2(496, 190, 336, 120)  # inside the 4:3 view (x 120..840)
	RoundBox.fill(hud, box, Color(0.1, 0.05, 0.1, 0.85), 24.0)
	hud.draw_string(font, box.position + Vector2(0, 50), run.area["name"], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 26, Color(1.0, 0.85, 0.3))
	hud.draw_string_outline(font, box.position + Vector2(0, 100), "Yes!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 40, 7, DARK)
	hud.draw_string(font, box.position + Vector2(0, 100), "Yes!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 40, INK)
	_draw_gems(font)


## The gem count just left of the menu button in the top right corner; a
## longer number grows to the left.
func _draw_gems(font: Font) -> void:
	var gem: Texture2D = tex["gem"]
	var text := str(int(save.get("gems", 0)) - gems_unshown)
	var right := GameMenu.button_rect(get_viewport()).position.x - 8.0
	var x := right - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, GEMS_FONT).x
	gem_icon = Vector2(x - 46, GEMS_Y) + gem.get_size() / 2.0
	# a little jump as each chest gem lands
	var j := 1.0 + 0.35 * gem_pop
	var size := gem.get_size() * j
	hud.draw_texture_rect(gem, Rect2(gem_icon - size / 2.0 - Vector2(0, 6.0 * gem_pop), size), false)
	var lift := Vector2(0, -6.0 * gem_pop)
	hud.draw_string_outline(font, Vector2(x, GEMS_Y + 30) + lift, text, HORIZONTAL_ALIGNMENT_LEFT, -1, GEMS_FONT, 6, DARK)
	hud.draw_string(font, Vector2(x, GEMS_Y + 30) + lift, text, HORIZONTAL_ALIGNMENT_LEFT, -1, GEMS_FONT,
			INK.lerp(Color(1.0, 0.85, 0.3), gem_pop))


## The open chest's gems, in screen space so they can fly up to the counter.
## Per gem (local time u, each starting GEM_STAGGER after the one before): a
## burst up out of the lid with a spin and a pop (to GEM_HANG), a twinkling
## hang, then a swoop to the counter that lands at GEM_LAND.
func _draw_chest_gems() -> void:
	if opening < 0:
		return
	var gem: Texture2D = tex["gem"]
	var lid := _to_screen(Vector2(_space_x(opening) + 46, FEET_Y - 40))
	for k in gem_count:
		var u := gem_fly - GEM_STAGGER * k
		if u < 0.0 or u >= GEM_LAND:
			continue
		var side := (k - (gem_count - 1) / 2.0) * 46.0 + (18.0 if gem_count == 1 else 0.0)
		var top := lid + Vector2(side, -130)
		var p: Vector2
		var sc := 1.0
		var spin := 1.0
		if u < GEM_HANG:
			var e := u / GEM_HANG
			# up and out on an arc that overshoots a little, then settles
			var rise := sin(e * PI * 0.62) / sin(PI * 0.62)
			p = lid.lerp(top, rise) + Vector2(0, -14.0 * sin(e * PI))
			sc = 0.5 + 0.8 * e - 0.3 * maxf(0.0, e - 0.7) / 0.3
			spin = cos(e * TAU * 1.5)
			# sparkles thrown out of the lid with it
			for m in 5:
				var a := TAU * (m / 5.0) + k
				var r := 18.0 + 60.0 * e
				_sparkle(lid + Vector2(cos(a), sin(a) * 0.6 - 0.4) * r, 7.0 * (1.0 - e), 1.0 - e)
		elif u < GEM_SWOOP:
			# hanging over the chest, bobbing and turning to catch the light
			var h := u - GEM_HANG
			p = top + Vector2(0, -5.0 * sin(h * 14.0))
			spin = cos(h * 9.0)
			_sparkle(p + Vector2(16, -14), 6.0 * absf(sin(h * 11.0)), 1.0)
		else:
			# swoop to the counter: out to the side first, then in fast
			var e := (u - GEM_SWOOP) / (GEM_LAND - GEM_SWOOP)
			var ez := e * e
			var ctrl := Vector2(top.x + 120.0, top.y - 120.0)
			p = top.lerp(ctrl, ez).lerp(ctrl.lerp(gem_icon, ez), ez)
			sc = 1.0 - 0.3 * ez
			# a short trail of sparkles behind it
			for m in 3:
				var back := maxf(0.0, ez - 0.07 * (m + 1))
				var q := top.lerp(ctrl, back).lerp(ctrl.lerp(gem_icon, back), back)
				_sparkle(q, 5.0 - m, 0.8 - 0.25 * m)
		var size := gem.get_size() * sc * 1.5  # bigger than the counter's gem: easy to follow
		# the spin: the gem narrows and widens as if it turns
		var w := maxf(0.15, absf(spin)) * size.x
		hud.draw_texture_rect(gem, Rect2(p - Vector2(w, size.y) / 2.0, Vector2(w, size.y)), false,
				Color(1, 1, 1) if spin >= 0.0 else Color(0.85, 0.8, 1.0))


## A four-pointed twinkle.
func _sparkle(c: Vector2, r: float, a: float) -> void:
	if r <= 0.5 or a <= 0.0:
		return
	var col := Color(1.0, 0.95, 0.7, a)
	hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, 0), c + Vector2(0, r), c + Vector2(-r * 0.25, 0)]), col)
	hud.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r * 0.25), c + Vector2(r, 0), c + Vector2(0, r * 0.25)]), col)


func _draw_overlay() -> void:
	if fade > 0.0:
		overlay.draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, fade))
	if not debug_on:
		return
	var font := ThemeDB.fallback_font
	var lines := [
		"seed %d  attempt %d  space %d/%d  phase %s  gems %d" % [run.run_seed, run.attempt, run.pos, run.length(),
				run.phase, run.gems],
		"rng 0x%08x  grade %s" % [run.rng.get_state(), run.grade["name"]],
	]
	if run.has_problem():
		lines.append("%s %s  answer %d" % [run.problem["op"], str(run.problem["dice"]), run.problem["answer"]])
	for i in lines.size():
		overlay.draw_rect(Rect2(124, 140 + i * 20, 712, 20), Color(0, 0, 0, 0.7))
		overlay.draw_string(font, Vector2(128, 155 + i * 20), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.6))


var _monster_cache := {}

func _monster_tex(id: String) -> Texture2D:
	if not _monster_cache.has(id):
		_monster_cache[id] = WorldTheme.monster_texture(id)
	return _monster_cache[id]
