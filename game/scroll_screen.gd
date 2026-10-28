## The lava crossing: a long row of rocks in the lava, crossed left to right.
## Each turn the child rolls two dice (add or subtract, answer 1 to 5) and taps
## the rock that many spaces ahead. Drives ScrollRun (all rules live there)
## and only animates what it returns. The world scrolls under a fixed HUD;
## both are drawn in the 960x540 design space.
extends Node2D

signal finished
signal rolled

const ScrollRun := preload("res://logic/path/scroll_run.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const InputGate := preload("res://logic/core/input_gate.gd")
const SaveStore := preload("res://game/save_store.gd")
const DieView := preload("res://game/ui/die_view.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")

const ART := "res://art/lava/"
const STRIP_SCALE := 3.0
const SPACE0_X := 190.0
const STEP := 120.0
const WATER_Y := 452.0      # where the rocks meet the lava
const ROCK_WATERLINE := 64.0  # the waterline row inside a rock sprite
const FEET_Y := WATER_Y - 34.0
const HERO_SCREEN_X := 220.0
const MONSTER_SCALE := 0.625
const CHEST_SCALE := 0.7
const TRAY := Rect2(300, 8, 360, 150)
const DICE_Y := 66.0
const BUBBLE := Rect2(124, 20, 150, 52)
const GEMS_AT := Vector2(752, 26)
const BAR := Rect2(140, 516, 680, 10)
const DEBUG_CORNER := Rect2(120, 0, 90, 60)
const FLICK_PX := 24.0
const HOP_S := 0.34
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const MONSTER_ART := {"blorp": "blorp-idle", "craggy": "blorp-idle-alt"}
## Event rocks wear a marker (yellow treasure, red enemy) from the start; what
## is on them stays hidden until the slime lands there. false hides the
## markers too, so every rock looks the same until it is reached.
const MARKERS_AHEAD := true
const MARKER_Y := WATER_Y - 60.0
const MARKER_SCALE := 1.5

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

var cam_x := 0.0
var hero_x := SPACE0_X
var hero_lift := 0.0
var hero_frame := "idle-0"
var hero_sink := 0.0
var sink_space := -1
var rock_sink := 0.0
var beaten := {}       # monster spaces beaten this attempt
var revealed := -1     # the event space the slime is on, its contents shown
var reveal := 0.0      # 0..1 pop-in of the revealed chest or monster
var lid_open := false
var opening := -1      # chest space whose gems are flying
var gem_fly := 0.0
var gem_count := 0
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
	for f in ["strip", "marker-treasure", "marker-enemy", "tile-wall-basalt", "rock-1", "rock-2", "rock-3", "chest-closed", "chest-open", "gem",
			"blorp-idle", "blorp-idle-alt", "slime-idle-0", "slime-idle-1", "slime-blink", "slime-hop-squash",
			"slime-hop-stretch", "slime-hop-air"]:
		tex[f] = load(ART + f + ".png")
	world = Node2D.new()
	world.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(world)
	world.draw.connect(_draw_world)
	choice = ChoiceWidget.new()
	world.add_child(choice)
	hud = Node2D.new()
	hud.z_index = 2
	add_child(hud)
	hud.draw.connect(_draw_hud)
	for i in 2:
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
		_ask("Roll!")
		await _wait_for_roll()
		var p := run.roll()
		await _roll_dice(p)
		_ask("Where?")
		var rects := []
		for d in p["choices"]:
			rects.append(_rock_rect(run.pos + d))
		choice.present(rects, 0)
		var pick: int = await choice.picked
		var out := run.choose(pick)
		for d in dice:
			d.show_numeral()
		await _hop_along(out["from"], out["to"])
		match out["result"]:
			"sink":
				await _sink(out["to"])
				await _restart()
			"chest":
				await _reveal(out["to"])
				await _open_chest(out["to"], out["gems"])
			"monster":
				await _reveal(out["to"])
				_say("Fight!")
				await _wait(0.5)
				await _fight()
			"goal":
				pass
			"hop":
				_cheer("Yes!")
				await _wait(0.3)
		_hide_dice()
		_save_progress()


func _wait_for_roll() -> void:
	tray_waiting = true
	tray_gate.present(Time.get_ticks_msec())
	await rolled
	tray_waiting = false
	tray_gate.close()


## Add: two wood dice. Subtract: the first die wood, the one taken away red.
func _roll_dice(p: Dictionary) -> void:
	Beeper.roll()
	op_sign = "+" if p["op"] == "add" else "-"
	op_alpha = 0.0
	var xs := [TRAY.get_center().x - 80.0, TRAY.get_center().x + 80.0]
	for i in 2:
		var d: DieView = dice[i]
		var red: bool = i == 1 and p["op"] == "sub"
		d.slip = red
		d.position = Vector2(xs[i], DICE_Y)
		d.roll_to(p["dice"][i], 0.12 * i)
	while not (dice[0].face_on and dice[1].face_on):
		await get_tree().process_frame
	await _tween_prop("op_alpha", 1.0, 0.2)
	for d in dice:
		d.countable = true


func _hide_dice() -> void:
	for d in dice:
		d.visible = false
		d.countable = false
	op_alpha = 0.0


func _save_progress() -> void:
	if run.phase == ScrollRun.CLEARED:
		SaveData.add_mark(save, run.area["id"], run.grade["id"])
		save["run"] = null
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
	f.setup(run.rng, run.grade["id"], run.current_monster(), false, false, debug_on)
	await _fade_to(1.0)
	add_child(f)
	await _fade_to(0.0)
	var won: bool = await f.done
	debug_on = f.debug_on
	await _fade_to(1.0)
	f.queue_free()
	var out := run.resolve_fight(won)
	if out["restarted"]:
		await _restart()
	else:
		beaten[run.pos] = true
		await _fade_to(0.0)
		_cheer("Yes!")


func _cleared() -> void:
	_save_progress()
	cleared_banner = true
	_cheer("Yes!")
	await _wait(0.5)
	_cheer("Yes!")
	_ask("Map")
	hud_choice.present([Rect2(400, 250, 160, 90)])
	await hud_choice.picked


# --- animations ------------------------------------------------------------

## The slime hops rock by rock, each hop counted, with a squash before the
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


## A wrong rock: it tips into the lava and the slime sinks with a blorp.
func _sink(space: int) -> void:
	sink_space = space
	Beeper.blorp()
	_say("Oops!")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rock_sink", 1.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hero_sink", 1.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	await _wait(0.6)


## The fail rule: back to the start of the crossing.
func _restart() -> void:
	await _fade_to(1.0)
	_hide_dice()
	beaten.clear()
	revealed = -1
	sink_space = -1
	rock_sink = 0.0
	hero_sink = 0.0
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


func _open_chest(space: int, n: int) -> void:
	lid_open = true
	opening = space
	gem_count = n
	gem_fly = 0.0
	SaveData.add_gems(save, n)
	_cheer("+%d" % n)
	Beeper.gems(n)
	await _tween_prop("gem_fly", 1.0, 1.1)
	opening = -1


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


func _on_pip_tapped(count: int) -> void:
	Beeper.count(count)
	_say(str(count))


# --- input -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	cam_x = lerpf(cam_x, _cam_target(), minf(1.0, delta * 6.0))
	world.position.x = -roundf(cam_x)
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
	if drag:
		if _tray_down and pos.distance_to(_tray_down_at) >= FLICK_PX:
			_tray_down = false
			rolled.emit()
		return
	if press:
		if tray_waiting and TRAY.has_point(pos) and tray_gate.accepts(Time.get_ticks_msec()):
			_tray_down = true
			_tray_down_at = pos
		elif BUBBLE.has_point(pos) and question != "":
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
	return SPACE0_X + STEP * i


func _world_w() -> float:
	return tex["strip"].get_width() * STRIP_SCALE


## Keeps the slime near the left so the next five rocks are on screen.
func _cam_target() -> float:
	return clampf(hero_x - HERO_SCREEN_X, 0.0, _world_w() - 960.0)


func _rock_rect(i: int) -> Rect2:
	return Rect2(_space_x(i) - 58, WATER_Y - 62, 116, 80)


# --- drawing ---------------------------------------------------------------

func _draw_world() -> void:
	var strip: Texture2D = tex["strip"]
	world.draw_texture_rect(strip, Rect2(Vector2.ZERO, strip.get_size() * STRIP_SCALE), false)
	# a little shimmer on the lava
	var glow := 0.05 + 0.05 * sin(_t * 2.2)
	world.draw_rect(Rect2(0, 380, _world_w(), 160), Color(1.0, 0.7, 0.2, glow))
	# the ledges at the start and the far shore
	var wall: Texture2D = tex["tile-wall-basalt"]
	var start_ledge := Rect2(-40, FEET_Y, SPACE0_X + 56, 200)
	var end_ledge := Rect2(_space_x(run.length()) - 56, FEET_Y, 1200, 200)
	for r in [start_ledge, end_ledge]:
		world.draw_texture_rect(wall, r, true)
		world.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(0.45, 0.3, 0.5))
	_draw_goal(Vector2(_space_x(run.length()) + 60, FEET_Y))
	# rocks
	for i in range(1, run.length()):
		var rock: Texture2D = tex["rock-%d" % (i % 3 + 1)]
		var p := Vector2(_space_x(i) - rock.get_width() / 2.0, WATER_Y - ROCK_WATERLINE)
		if i == sink_space:
			p.y += rock_sink * 46.0
			_draw_clipped(rock, p, WATER_Y + 12.0, 1.0 - rock_sink * 0.5)
		else:
			world.draw_texture(rock, p)
	# markers on event rocks not reached yet
	for i in range(1, run.length()):
		var kind := _event_at(i)
		if kind == "" or i == revealed or not MARKERS_AHEAD or i == sink_space:
			continue
		var m: Texture2D = tex["marker-treasure" if kind == "chest" else "marker-enemy"]
		var bob := sin(_t * 2.5 + i * 0.7) * 3.0
		var ms := m.get_size() * MARKER_SCALE
		world.draw_texture_rect(m, Rect2(Vector2(_space_x(i), MARKER_Y + bob) - ms / 2.0, ms), false)
	# the slime
	_draw_hero()
	# the monster on the rock just reached, beside the slime and facing it
	if revealed >= 0 and _event_at(revealed) == "monster":
		var s := run.space_at(revealed)
		var t: Texture2D = tex[MONSTER_ART.get(s["monster"], "blorp-idle")]
		var size := t.get_size() * MONSTER_SCALE * _pop()
		var breathe := sin(_t * 2.0) * 2.0
		var c := Vector2(_space_x(revealed) + 84, FEET_Y + 6)
		# the art faces right; a negative width mirrors it to face the slime
		world.draw_texture_rect(t, Rect2(c + Vector2(size.x / 2, -size.y - breathe), Vector2(-size.x, size.y + breathe)), false)
	# the chest on the rock just reached, in front of the slime so it stays in view
	if revealed >= 0 and run.space_at(revealed).get("type") == "chest":
		var t: Texture2D = tex["chest-open" if lid_open else "chest-closed"]
		var size := t.get_size() * CHEST_SCALE * _pop()
		var c := Vector2(_space_x(revealed) + 46, FEET_Y + 6)
		world.draw_texture_rect(t, Rect2(c - Vector2(size.x / 2, size.y), size), false)
	# gems flying out of an opened chest
	if opening >= 0:
		var gem: Texture2D = tex["gem"]
		for k in gem_count:
			var spread := (k - (gem_count - 1) / 2.0) * 34.0
			var e := gem_fly
			var p := Vector2(_space_x(opening) + 46 + spread * minf(1.0, e * 2.0), FEET_Y - 60 - 120 * sin(minf(1.0, e * 1.4) * PI * 0.5))
			world.draw_texture(gem, p - gem.get_size() / 2.0, Color(1, 1, 1, 1.0 - maxf(0.0, e - 0.7) / 0.3))


## "chest" or "monster" while that space still holds something, else "".
## An opened chest is empty for good; a beaten monster is gone this attempt.
func _event_at(i: int) -> String:
	var s := run.space_at(i)
	match s.get("type", ""):
		"chest":
			return "" if run.looted.has(i) and i != revealed else "chest"
		"monster":
			return "" if beaten.has(i) else "monster"
	return ""


## The pop-in scale of a revealed chest or monster, with a little overshoot.
func _pop() -> float:
	return lerpf(0.3, 1.0, reveal) + 0.15 * sin(reveal * PI)


func _draw_hero() -> void:
	var t: Texture2D = tex["slime-" + hero_frame]
	var feet := Vector2(hero_x, FEET_Y - hero_lift + hero_sink * 120.0)
	var pos := feet - Vector2(t.get_width() / 2.0, t.get_height())
	if hero_sink > 0.0:
		_draw_clipped(t, pos, WATER_Y - 4.0, 1.0)
		# bubbles where it went under
		for k in 4:
			var ph := fmod(_t * 1.7 + k * 0.27, 1.0)
			world.draw_circle(Vector2(hero_x - 30 + k * 20, WATER_Y - 6 - ph * 22.0), 5.0 * (1.0 - ph) + 1.0,
					Color(1.0, 0.85, 0.4, (1.0 - ph) * minf(1.0, hero_sink * 3.0)))
	else:
		world.draw_circle(Vector2(hero_x, FEET_Y + 2), 30.0 - hero_lift * 0.25, Color(0, 0, 0, 0.25))
		world.draw_texture(t, pos)


## Draws only the part of a sprite above the lava line, so it sinks into it.
func _draw_clipped(t: Texture2D, pos: Vector2, line_y: float, alpha: float) -> void:
	var h := clampf(line_y - pos.y, 0.0, t.get_height())
	if h <= 0.0:
		return
	world.draw_texture_rect_region(t, Rect2(pos, Vector2(t.get_width(), h)), Rect2(0, 0, t.get_width(), h),
			Color(1, 1, 1, alpha))


func _draw_goal(base: Vector2) -> void:
	# a glowing way out on the far shore
	world.draw_rect(Rect2(base + Vector2(-50, -150), Vector2(100, 150)), Color(0.12, 0.07, 0.12))
	world.draw_arc(base + Vector2(0, -150), 50.0, PI, TAU, 24, Color(0.12, 0.07, 0.12), 20.0)
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	world.draw_rect(Rect2(base + Vector2(-38, -140), Vector2(76, 140)), Color(1.0, 0.85, 0.4, 0.35 * pulse))
	world.draw_circle(base + Vector2(0, -170), 14.0, Color(1.0, 0.85, 0.3, pulse))


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	# dice tray
	hud.draw_rect(TRAY, Color(0.1, 0.05, 0.1, 0.8))
	hud.draw_rect(TRAY, Color(0.45, 0.3, 0.5), false, 3.0)
	if tray_waiting:
		var a := 0.5 + 0.5 * sin(_t * 5.0)
		hud.draw_rect(TRAY.grow(3), Color(1.0, 0.92, 0.3, a), false, 4.0)
		hud.draw_string(font, TRAY.position + Vector2(0, 90), "Roll", HORIZONTAL_ALIGNMENT_CENTER, TRAY.size.x, 40, INK)
	if op_alpha > 0.0:
		# plus or minus between the dice, coloured and gently pulsing
		DiceDraw.draw_op(hud, Vector2(TRAY.get_center().x, DICE_Y), op_sign, 44.0, _t, op_alpha)
	# speech bubble (tap it to hear the question again)
	if bubble != "":
		hud.draw_rect(BUBBLE, INK)
		hud.draw_rect(BUBBLE, DARK, false, 3.0)
		hud.draw_string(font, BUBBLE.position + Vector2(0, 37), bubble, HORIZONTAL_ALIGNMENT_CENTER, BUBBLE.size.x, 30, DARK)
	# gems
	var gem: Texture2D = tex["gem"]
	hud.draw_texture(gem, GEMS_AT)
	hud.draw_string(font, GEMS_AT + Vector2(46, 30), str(save.get("gems", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	# progress along the crossing: one tick per space
	var n := run.length()
	hud.draw_rect(BAR.grow(3), Color(0.1, 0.05, 0.1, 0.8))
	hud.draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * run.pos / n, BAR.size.y)), Color(0.4, 0.85, 0.65))
	for i in range(1, n + 1):
		var x := BAR.position.x + BAR.size.x * i / n
		var s := run.space_at(i)
		if s.get("type") == "chest" and not run.looted.has(i):
			hud.draw_circle(Vector2(x, BAR.get_center().y), 5.0, Color(1.0, 0.8, 0.2))
		elif s.get("type") == "monster" and not beaten.has(i):
			hud.draw_circle(Vector2(x, BAR.get_center().y), 5.0, Color(0.9, 0.2, 0.2))
	if cleared_banner:
		hud.draw_rect(Rect2(200, 160, 560, 200), Color(0.1, 0.05, 0.1, 0.85))
		hud.draw_string(font, Vector2(200, 220), run.area["name"], HORIZONTAL_ALIGNMENT_CENTER, 560, 34, Color(1.0, 0.85, 0.3))
		hud.draw_rect(Rect2(400, 250, 160, 90), Color(0.25, 0.5, 0.3))
		hud.draw_string(font, Vector2(400, 308), "Map", HORIZONTAL_ALIGNMENT_CENTER, 160, 36, INK)


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
