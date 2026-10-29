## The Match Bounce graybox: one boss fight on one board with placeholder
## shapes. Drives BounceFight (all rules live there) and only animates what
## it returns. Drawn in the 960x540 design space; everything the child
## touches sits inside the 4:3 safe area, x 120..840.
##
## Each shot starts with the boss's turn: it spits its number out as rolled
## dice (the same tumble as the crossing dice), and the choices open when they
## land. Then: tap the peg face that matches the boss's number (left column),
## then touch the board and drag to aim; let go to fire. A short stub shows
## the direction only. The flight steps the logic at a fixed 120 Hz.
## Controller: d-pad names, left/right aims, A fires.
extends Node2D

signal done(won: bool)

const BounceFight := preload("res://logic/bounce/bounce_fight.gd")
const BounceSim := preload("res://logic/bounce/bounce_sim.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const DieView := preload("res://game/ui/die_view.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

## Peg colours by face. Acorn uses 1 to 3; the colour helps the eye, the
## count is the answer.
const FACE_COLORS := {
	1: Color(0.25, 0.55, 0.95),
	2: Color(0.3, 0.8, 0.35),
	3: Color(0.98, 0.6, 0.15),
	4: Color(0.85, 0.3, 0.75),
	5: Color(0.95, 0.85, 0.2),
	6: Color(0.4, 0.85, 0.9),
}
## Pixel-art pegs by face: a gem and a tint (white keeps the gem's colour).
const PEG_ART := {
	1: ["blue", Color.WHITE],
	2: ["green", Color.WHITE],
	3: ["orange", Color.WHITE],
	4: ["purple", Color(1.25, 0.85, 1.1)],
	5: ["orange", Color(1.25, 1.25, 0.45)],
	6: ["blue", Color(0.7, 1.3, 1.3)],
}
const PEG_ART_SCALE := 1.25    # 32 px gems drawn to fill a 40 px peg
const BUMPER_ART_SCALE := 1.375
const DRAGON_TEX := preload("res://art/boss/skeleton-dragon.png")
const TREASURE_TEX := preload("res://art/boss/treasure-cave.png")
const BOARD_TEX := preload("res://art/boss/board.png")
const BUMPER_TEX := preload("res://art/boss/bumper.png")
const BALL_TEX := preload("res://art/ui/ball.png")
const HEART_TEX := preload("res://art/ui/heart.png")
const HEART_EMPTY_TEX := preload("res://art/ui/heart-empty.png")
## The Skeleton Dragon fills the top right: its skull sits right of the
## board and its neck runs off the screen to the right and up.
const DRAGON_AT := Vector2(700, -96)
const DRAGON_SCALE := 2.5
const INK := Color(0.96, 0.94, 0.9)
const OUTLINE := Color(0.08, 0.03, 0.03)
const WALL := Color(0.55, 0.42, 0.35)

const CHOICE_X := 172.0
const CHOICE_SIZE := 76.0
const CHOICE_GAP := 96.0
const BOSS_POS := Vector2(820, 96)   # the skull
const STUB_LENGTH := 70.0
const AIM_KEY_SPEED := 600.0   # tenths of a degree per second
const BOSS_DIE_SCALE := 1.0    # full 96 px dice
const BOSS_DIE_AT := Vector2(800, 318)
const BOSS_JAW := Vector2(770, 170)
const FLOAT_S := 1.1
const FIRST_FACE_Y := 150.0

var fight
var debug_on := false
var choice: ChoiceWidget

var phase := "naming"   # naming, aiming, flying, won, lost
var aim := 0
var aiming_touch := false
var _acc := 0.0
var slow := false
var _t := 0.0
var bubble := ""
var bubble_t := 0.0
var boss_flash := 0.0
var wobble := {}        # peg index -> seconds left
var pop_rings := []     # [pos, color, age]
var pop_count := 0
var fail_buttons: Array[Rect2] = []
var boss_dice: Array = []
var floaters := []      # damage numbers: [text, pos, age]
var slow_t := 0.0       # seconds since the last-heart slow-down began
var ball_pop := 0.0     # 1 when the ball has just taken the boss's roll
var slow_mo := 0.3      # time scale on the last heart, from tuning.json "screen"
var peg_tex := {}


func setup(rng, grade: int, show_debug := false) -> void:
	fight = BounceFight.new(rng, grade)
	slow_mo = float(BounceFight.load_tuning()["screen"]["last_heart_time_scale"])
	debug_on = show_debug


func _ready() -> void:
	for c in ["blue", "green", "orange", "purple"]:
		peg_tex[c] = load("res://art/boss/peg-%s.png" % c)
	for i in 2:
		var d := DieView.new()
		d.scale = Vector2.ONE * BOSS_DIE_SCALE
		d.visible = false
		add_child(d)
		boss_dice.append(d)
	choice = ChoiceWidget.new()
	add_child(choice)
	choice.picked.connect(_on_named)
	_start_naming()


func _start_naming() -> void:
	phase = "naming"
	aim = 0
	pop_count = 0
	if fight.refills > 0 and fight.shot_count > 0 and _all_pegs_back():
		_say("New pegs!")
	await _boss_rolls()
	if phase != "naming":
		return
	if fight.auto_name():
		await _ball_takes_roll()
	else:
		choice.present(_choice_rects())


## Acorn: no naming step. The boss's dots jump onto the ball, which swells
## for a moment, and the child goes straight to aiming.
func _ball_takes_roll() -> void:
	fight.name_for_child()
	Beeper.count(fight.target)
	ball_pop = 1.0
	create_tween().tween_property(self, "ball_pop", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.3).timeout
	phase = "aiming"


## The boss's turn: its number tumbles out of the jaw as one die (1 to 6) or
## two dice side by side (7 to 12, like DiceDraw.draw_value). Bigger numbers
## stay a numeral.
func _boss_rolls() -> void:
	var faces := DiceDraw.split_value(fight.target)
	for d in boss_dice:
		d.visible = false
	if faces.is_empty():
		return
	Beeper.roll()
	for i in faces.size():
		var d: DieView = boss_dice[i]
		d.position = BOSS_DIE_AT + Vector2((i - (faces.size() - 1) / 2.0) * 104.0, 0)
		d.roll_to(faces[i], 0.12 * i, (BOSS_JAW - d.position) / BOSS_DIE_SCALE)
	while true:
		await get_tree().process_frame
		var all_on := true
		for i in faces.size():
			all_on = all_on and boss_dice[i].face_on
		if all_on:
			return



func _all_pegs_back() -> bool:
	return not fight.peg_alive.has(false)


func _on_named(index: int) -> void:
	fight.name_peg(index)
	Beeper.count(fight.named_face)
	phase = "aiming"


func _fire() -> void:
	phase = "flying"
	aiming_touch = false
	fight.fire(aim)
	_acc = 0.0
	slow = false
	slow_t = 0.0
	if not fight.named_right:
		_say("Ha ha!")


func _on_shot_over() -> void:
	var out: Dictionary = fight.end_shot()
	slow = false
	if out["state"] == BounceFight.State.WON:
		phase = "won"
		_say("You win!")
		Beeper.good()
		await get_tree().create_timer(2.5).timeout
		done.emit(true)
		return
	if out["state"] == BounceFight.State.LOST:
		phase = "lost"
		for d in boss_dice:
			d.visible = false
		Beeper.bad()
		return
	if out["damage"] == 0 and fight.named_right:
		_say("Oh no!")
	_start_naming()


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == "lost":
		if Pointer.is_press(event):
			var p := Pointer.local_pos(self, event)
			if fail_buttons.size() == 2 and fail_buttons[0].has_point(p):
				done.emit(false)   # Try: the owner starts the fight again
			elif fail_buttons.size() == 2 and fail_buttons[1].has_point(p):
				done.emit(false)   # Map: no map in this graybox yet
		return
	if phase != "aiming":
		return
	if Pointer.is_press(event):
		var p := Pointer.local_pos(self, event)
		if _board_rect().has_point(p):
			aiming_touch = true
			_aim_at(p)
	elif Pointer.is_drag(event) and aiming_touch:
		_aim_at(Pointer.local_pos(self, event))
	elif Pointer.is_release(event) and aiming_touch:
		_fire()


func _aim_at(p: Vector2) -> void:
	var d := p - BounceSim.launcher(fight.board)
	if d.y < 1.0:
		d.y = 1.0
	aim = BounceSim.clamp_aim(roundi(rad_to_deg(atan2(d.x, d.y)) * 10.0), fight.phys)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("debug"):
		debug_on = not debug_on
	boss_flash = maxf(0.0, boss_flash - delta * 3.0)
	bubble_t = maxf(0.0, bubble_t - delta)
	for k in wobble.keys():
		wobble[k] -= delta
		if wobble[k] <= 0.0:
			wobble.erase(k)
	for r in pop_rings:
		r[2] += delta
	pop_rings = pop_rings.filter(func(r): return r[2] < 0.5)
	for f in floaters:
		f[2] += delta
	floaters = floaters.filter(func(f): return f[2] < FLOAT_S)
	if slow:
		slow_t += delta
	if phase == "aiming":
		var dir := Input.get_axis("move_left", "move_right")
		if absf(dir) > 0.0:
			aim = BounceSim.clamp_aim(aim - roundi(dir * AIM_KEY_SPEED * delta), fight.phys)
		if Input.is_action_just_pressed("pick"):
			_fire()
	elif phase == "flying":
		_fly(delta)
	queue_redraw()


## Steps the logic at its fixed rate. Real time only decides how many steps
## run this frame, so the flight is the same at any frame rate.
func _fly(delta: float) -> void:
	var dt: float = fight.phys["dt"]
	_acc += delta * (slow_mo if slow else 1.0)
	while _acc >= dt and fight.sim.ended == BounceSim.End.NONE:
		_acc -= dt
		for e in fight.sim.step():
			_on_event(e)
	if fight.sim.ended != BounceSim.End.NONE:
		phase = "settling"
		await get_tree().create_timer(0.5).timeout
		_on_shot_over()


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		"pop":
			var p: Dictionary = fight.board["pegs"][e["peg"]]
			pop_rings.append([Vector2(p["x"], p["y"]), FACE_COLORS.get(int(p["face"]), INK), 0.0])
			pop_count += 1
			Beeper.count(pop_count + 2)
			boss_flash = 1.0
			_float_damage(int(e["damage"]))
			if e["damage"] > 1:
				_say("Combo!")
			if not slow and fight.is_lethal():
				# The last heart: time slows, the ball and pegs warble, and the
				# pop lands with a fanfare.
				slow = true
				Beeper.warble()
		"whiff":
			wobble[e["peg"]] = 0.35
			Beeper.tone(150.0, 0.04, -20.0)
		"mod":
			Beeper.tone(880.0, 0.1)
		"bounce":
			Beeper.tone(300.0, 0.03, -22.0)


func _say(text: String) -> void:
	bubble = text
	bubble_t = 1.4


## A damage number that pops out of the boss and floats up. Hits close
## together fan out a little so each one can be read.
func _float_damage(n: int) -> void:
	var k := floaters.size() % 3
	floaters.append(["-%d" % n, BOSS_POS + Vector2((k - 1) * 58.0, -24.0 + k * 14.0), 0.0])


# --- layout ----------------------------------------------------------------

func _choice_rects() -> Array:
	var out := []
	var n: int = fight.choices.size()
	for i in n:
		var c := Vector2(CHOICE_X, FIRST_FACE_Y + CHOICE_GAP * i)
		out.append(Rect2(c - Vector2(CHOICE_SIZE, CHOICE_SIZE) / 2.0, Vector2(CHOICE_SIZE, CHOICE_SIZE)))
	return out


func _board_rect() -> Rect2:
	return Rect2(230, 40, 500, 500)


## The boss's hearts and the balls left. At Acorn there is no naming
## column, so they sit left of the board, inside the 4:3 safe area; above
## Acorn the naming column has that space, so they go right, under the dice.
func _hearts_panel() -> Rect2:
	return Rect2(124, 40, 100, 270) if fight.auto_name() else Rect2(744, 330, 196, 100)


func _balls_panel() -> Rect2:
	return Rect2(124, 330, 100, 200) if fight.auto_name() else Rect2(744, 440, 196, 92)


func _bubble_rect() -> Rect2:
	return Rect2(745, 400, 150, 46) if fight.auto_name() else Rect2(745, 190, 150, 46)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.06, 0.04, 0.05))
	# the dragon's hoard: gold and jewels heaped left, right and behind
	draw_texture_rect(TREASURE_TEX, Rect2(0, 0, 960, 540), false)
	draw_texture_rect(BOARD_TEX, _board_rect(), false, Color(1, 1, 1, 0.9))
	_draw_dragon()
	var b: Dictionary = fight.board
	for w in b["walls"]:
		draw_line(Vector2(w[0], w[1]), Vector2(w[2], w[3]), WALL, 6.0)
	for bm in b["bumpers"]:
		# the movement peg: a brass bumper the ball bounces off
		var bs := BUMPER_TEX.get_size() * BUMPER_ART_SCALE * float(bm["r"]) / 22.0
		draw_texture_rect(BUMPER_TEX, Rect2(Vector2(bm["x"], bm["y"]) - bs / 2.0, bs), false)
	_draw_pegs(font)
	for r in pop_rings:
		var k: float = r[2] / 0.5
		draw_arc(r[0], 20.0 + 30.0 * k, 0, TAU, 24, Color(r[1], 1.0 - k), 5.0)
	_draw_launcher(font)
	_draw_ball()
	_draw_boss(font)
	_draw_balls_left()
	if not fight.auto_name():
		_draw_choices(font)
	if bubble_t > 0.0:
		var br := _bubble_rect()
		RoundBox.fire(self, br, _t, 16.0)
		_outlined(font, br.position + Vector2(0, 32), bubble, br.size.x, 26)
	_draw_floaters(font)
	if phase == "lost":
		_draw_fail(font)
	if debug_on:
		var line := "target %d ball %d answer %d named %d live %d hearts %d balls %d refills %d aim %d" % [
			fight.target, fight.ball_value, fight.answer_face, fight.named_face, fight.live_count(),
			fight.boss_hearts, fight.balls_left, fight.refills, aim]
		draw_rect(Rect2(124, 4, 712, 20), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(128, 19), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.6))


func _peg_alive(i: int) -> bool:
	if phase in ["flying", "settling"] and fight.sim != null:
		return fight.sim.peg_alive[i]
	return fight.peg_alive[i]


func _draw_pegs(font: Font) -> void:
	var b: Dictionary = fight.board
	var r: float = b["peg_radius"]
	for i in b["pegs"].size():
		if not _peg_alive(i):
			continue
		var p: Dictionary = b["pegs"][i]
		var c := Vector2(p["x"], p["y"])
		if wobble.has(i):
			c.x += sin(wobble[i] * 60.0) * 4.0
		if slow:
			c += _warble(c) * 3.0
		var face := int(p["face"])
		var art: Array = PEG_ART.get(face, PEG_ART[1])
		var tint: Color = art[1]
		if wobble.has(i):
			tint = tint.darkened(0.4)
		_draw_peg_art(peg_tex[art[0]], c, r, tint)
		if fight.peg_labels() == "numerals":
			_outlined(font, c + Vector2(-r, r * 0.45), str(face), r * 2.0, int(r * 1.35))
		else:
			DiceDraw.draw_face(self, c, r * 1.2, face)
		if debug_on and phase == "naming" and face == fight.answer_face:
			draw_arc(c, r + 5, 0, TAU, 24, Color(0.6, 1, 0.6), 2.0)
	for i in b["mods"].size():
		var m: Dictionary = b["mods"][i]
		var c := Vector2(m["x"], m["y"])
		var used: bool = phase in ["flying", "settling"] and fight.sim != null and fight.sim.mod_used[i]
		_draw_peg_art(peg_tex["purple"], c, r, Color(1.5, 1.5, 1.5) if used else Color.WHITE)
		draw_arc(c, r + 2.0, 0, TAU, 24, Color(1.0, 0.85, 0.3), 3.0)
		var label := "+%d" % m["add"] if int(m["add"]) > 0 else str(m["add"])
		_outlined(font, c + Vector2(-r, 8), label, r * 2, 22)


func _draw_peg_art(t: Texture2D, c: Vector2, r: float, tint: Color) -> void:
	var size := t.get_size() * PEG_ART_SCALE * r / 20.0
	draw_texture_rect(t, Rect2(c - size / 2.0, size), false, tint)


## Light text with a dark outline: peg numerals and the fiery boxes.
func _outlined(font: Font, pos: Vector2, text: String, width: float, size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, maxi(4, size / 4), OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, INK)


func _draw_launcher(font: Font) -> void:
	var l := BounceSim.launcher(fight.board)
	draw_circle(l, 22.0, Color(0.35, 0.3, 0.28))
	if phase == "aiming":
		var dir := BounceSim.aim_dir(aim, fight.phys)
		# The fixed stub: the same length every time, never reaching a peg.
		draw_line(l + dir * 24.0, l + dir * (24.0 + STUB_LENGTH), Color(1, 0.95, 0.6, 0.8), 6.0)


func _draw_ball() -> void:
	var r: float = fight.phys["ball_radius"]
	var at := BounceSim.launcher(fight.board)
	var value: int = fight.ball_shows() if fight.named_face > 0 or not fight.auto_name() else 0
	if phase in ["flying", "settling"] and fight.sim != null:
		at = fight.sim.pos
		value = fight.ball_shows() if fight.auto_name() else fight.sim.ball_value
	r *= 1.0 + 0.6 * ball_pop
	if phase in ["naming", "aiming", "flying", "settling"]:
		var col := INK
		if fight.named_face > 0:
			col = FACE_COLORS.get(fight.named_face, INK).lightened(0.3)
		if slow and phase in ["flying", "settling"]:
			_draw_warble_ball(at, r + 3.0, col)
		else:
			# the pixel pearl, a little bigger while it carries a die face
			var rr := r + 7.0 if value > 0 else r
			var bs := Vector2.ONE * rr * 2.0 * 32.0 / 22.0
			var tint := Color.WHITE if fight.named_face <= 0 else col
			draw_texture_rect(BALL_TEX, Rect2(at - bs / 2.0, bs), false, tint)
		if value > 0:
			# The ball's die, drawn a little bigger than the ball so the dots
			# read while it flies.
			DiceDraw.draw_face(self, at, r * 2.0, value)


## The slowed ball: its rim ripples and rings ripple off it, so the child
## sees that the bounce itself is changed, not just slower.
func _draw_warble_ball(at: Vector2, r: float, col: Color) -> void:
	var k := minf(1.0, slow_t * 4.0)
	for ring in 3:
		var ph := fmod(slow_t * 1.6 + ring / 3.0, 1.0)
		var rr := r + 6.0 + ph * 34.0
		var pts := PackedVector2Array()
		for s in 33:
			var a := TAU * s / 32.0
			pts.append(at + Vector2(cos(a), sin(a)) * (rr + sin(a * 5.0 + slow_t * 9.0) * 3.0 * k))
		draw_polyline(pts, Color(1.0, 0.9, 0.5, (1.0 - ph) * 0.7 * k), 3.0)
	var body := PackedVector2Array()
	for s in 32:
		var a := TAU * s / 32.0
		body.append(at + Vector2(cos(a), sin(a)) * r * (1.0 + 0.16 * k * sin(a * 6.0 + slow_t * 18.0)))
	draw_colored_polygon(body, col)


## A slow wave across the board while time is slowed.
func _warble(c: Vector2) -> Vector2:
	var k := minf(1.0, slow_t * 4.0)
	return Vector2(sin(slow_t * 11.0 + c.y * 0.05), cos(slow_t * 9.0 + c.x * 0.05)) * k


## The big Skeleton Dragon: it flashes and shakes when a peg pops.
func _draw_dragon() -> void:
	var shake := Vector2(sin(_t * 70.0), cos(_t * 53.0)) * 6.0 * boss_flash
	var breathe := Vector2(0, sin(_t * 1.6) * 3.0)
	var glow := 1.0 + boss_flash * 1.2
	var size := DRAGON_TEX.get_size() * DRAGON_SCALE
	draw_texture_rect(DRAGON_TEX, Rect2(DRAGON_AT + shake + breathe, size), false, Color(glow, glow, glow))


## The boss's hearts and the balls left, in pixel art on fiery panels.
func _draw_boss(font: Font) -> void:
	# The target, spat out of the jaw as rolled dice (above 12 a numeral).
	if DiceDraw.split_value(fight.target).is_empty():
		DiceDraw.draw_value(self, BOSS_DIE_AT, 80.0, fight.target)
	var hp := _hearts_panel()
	RoundBox.fire(self, hp, _t, 16.0)
	var cols := 2 if fight.auto_name() else 5
	var top := hp.position + Vector2(hp.size.x / 2.0 - (cols - 1) * 18.0, 26)
	if fight.auto_name():
		_outlined(font, hp.position + Vector2(0, 30), "Dragon", hp.size.x, 22)
		top.y += 38
	for i in fight.boss_max_hearts:
		var c := top + Vector2((i % cols) * 36, (i / cols) * 36)
		draw_texture(HEART_TEX if i < fight.boss_hearts else HEART_EMPTY_TEX, c - Vector2(16, 16))


## Damage numbers: they pop in big, settle, float up and fade.
func _draw_floaters(font: Font) -> void:
	for f in floaters:
		var k: float = f[2] / FLOAT_S
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 6.0)
		var size := int(40.0 * pop)
		var at: Vector2 = f[1] + Vector2(0, -56.0 * k)
		var a := 1.0 - maxf(0.0, k - 0.6) / 0.4
		var pos := at + Vector2(-60, size * 0.35)
		draw_string_outline(font, pos, f[0], HORIZONTAL_ALIGNMENT_CENTER, 120, size, 8, Color(0.15, 0.02, 0.02, a))
		draw_string(font, pos, f[0], HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(1.0, 0.85, 0.2, a))


func _draw_balls_left() -> void:
	var bp := _balls_panel()
	RoundBox.fire(self, bp, _t, 16.0)
	var cols := 2 if fight.auto_name() else 5
	var top := bp.position + Vector2(bp.size.x / 2.0 - (cols - 1) * 18.0, 28)
	if fight.auto_name():
		_outlined(ThemeDB.fallback_font, bp.position + Vector2(0, 30), "Balls", bp.size.x, 22)
		top.y += 36
	var shown: int = fight.balls_left - (1 if phase in ["flying", "settling"] else 0)
	for i in maxi(0, shown):
		draw_texture(BALL_TEX, top + Vector2((i % cols) * 36, (i / cols) * 36) - Vector2(16, 16))


func _draw_choices(font: Font) -> void:
	var rects := _choice_rects()
	for i in rects.size():
		var rr: Rect2 = rects[i]
		var face: int = fight.choices[i]
		var lit: bool = phase != "naming" and face == fight.named_face
		var col: Color = FACE_COLORS.get(face, INK)
		if phase != "naming" and not lit:
			col = col.darkened(0.6)
		draw_circle(rr.get_center(), CHOICE_SIZE / 2.0, col)
		DiceDraw.draw_face(self, rr.get_center(), CHOICE_SIZE * 0.6, face)
	if phase == "naming":
		draw_string(font, Vector2(124, 100), "Pick", HORIZONTAL_ALIGNMENT_CENTER, 96, 26, INK)


func _draw_fail(font: Font) -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(120, 220), "No more balls", HORIZONTAL_ALIGNMENT_CENTER, 720, 40, INK)
	fail_buttons = [Rect2(300, 280, 160, 90), Rect2(500, 280, 160, 90)]
	var labels := ["Try", "Map"]
	for i in 2:
		RoundBox.fill(self, fail_buttons[i], Color(0.3, 0.6, 0.3) if i == 0 else Color(0.4, 0.4, 0.5), 18.0)
		draw_string(font, fail_buttons[i].position + Vector2(0, 58), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 160, 36, INK)
