## The Match Bounce graybox: one boss fight on one board with placeholder
## shapes. Drives BounceFight (all rules live there) and only animates what
## it returns. Drawn in the 960x540 design space; everything the child
## touches sits inside the 4:3 safe area, x 120..840.
##
## Each shot starts with the boss's turn: it spits its number out as rolled
## dice (the same tumble as the crossing dice), and the choices open when they
## land. Then: tap the peg face that matches the boss's number (left column),
## then touch the board and drag to aim; let go to fire. A dashed line shows
## the ball's path up to where it first hits something (Terrence 2026-11-07),
## worked out with the same sim the shot uses. The flight steps the logic at
## a fixed 120 Hz.
## Controller: d-pad names, left/right aims, A fires.
extends Node2D

signal done(won: bool)

const BounceFight := preload("res://logic/bounce/bounce_fight.gd")
const BounceSim := preload("res://logic/bounce/bounce_sim.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Ambient := preload("res://game/ui/ambient.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const DieView := preload("res://game/ui/die_view.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const SaveStore := preload("res://game/save_store.gd")
const PlayLog := preload("res://game/play_log.gd")
const GEM_TEX := preload("res://art/lava/gem.png")
## The gem bucket for beating the dragon (2026-11-06, Terrence): where it
## lands, and how long the pour takes.
const BUCKET_AT := Vector2(480, 330)
const BUCKET_DROP_S := 0.6
const BUCKET_POUR_S := 1.8

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
const BOARD_TEX := preload("res://art/boss/board.png")
const BUMPER_TEX := preload("res://art/boss/bumper.png")
const BALL_TEX := preload("res://art/ui/ball.png")
const HEART_TEX := preload("res://art/ui/heart.png")
const HEART_EMPTY_TEX := preload("res://art/ui/heart-empty.png")
## The Skeleton Dragon fills the top right: its skull sits right of the
## board and its neck curls down and off the screen to the right. Drawn on
## the one character grid (Look.CHAR_PX), 400 px art, nothing scaled.
## (DRAGON_AT, per world: see _load_theme)
## Its bony arm comes in from the body off screen right, and the claw at its
## end grips the right wall of the board, under the skull.
## (ARM_AT, per world: see _load_theme)
## The player's robot dragon watches from the bottom left.
const INK := Color(0.96, 0.94, 0.9)
## The right edge everything readable stays left of: the 1340x800 tablet
## (5:3) shows x 28..932 of the 960 wide frame, so keep a margin inside it.
const SAFE_RIGHT := 920.0
const OUTLINE := Color(0.08, 0.03, 0.03)
const WALL := Color(0.55, 0.42, 0.35)

const CHOICE_X := 172.0
const CHOICE_SIZE := 76.0
const CHOICE_GAP := 96.0
const BOSS_POS := Vector2(820, 96)   # the skull
const STUB_LENGTH := 70.0
## The aim line: dashes this long with gaps between, up to the first hit.
const DASH := 14.0
const DASH_GAP := 10.0
const AIM_MAX_STEPS := 600  # 5 s of flight at 120 Hz
const AIM_KEY_SPEED := 600.0   # tenths of a degree per second
const BOSS_DIE_SCALE := 1.0    # full 96 px dice
const BOSS_DIE_AT := Vector2(822, 400)  # two dice side by side still end at SAFE_RIGHT
const BOSS_JAW := Vector2(790, 250)
const FLOAT_S := 1.1
const FIRST_FACE_Y := 150.0

## The robot dragon, or the store hero in use (game/ui/look.gd).
var hero_tex: Texture2D = Look.hero_texture()
var fight
var debug_on := false
var choice: ChoiceWidget

var phase := "naming"   # naming, aiming, flying, won, lost
var aim := 0
var _aim_path := PackedVector2Array()  # the dashed line's points, for _aim_path_for
var _aim_path_for := 99999            # the aim (decidegrees) and shot it was worked out for
var _aim_path_shot := -1
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
var save: Dictionary = {}  # the profile; empty in the standalone graybox and tests (no gems banked)
## true when a lost fight ends on Map rather than Try.
var to_map := false
var persist := true        # false: stills and tests leave the profile file alone
var win_gems := 10         # the bucket, from tuning.json "screen" "win_gems"
var bucket_t := -1.0       # seconds since the bucket appeared; -1 before the win
var gems_shown := 0        # the bucket's gems counted into the corner so far


## The boss's world (Terrence 2026-11-08): its head, arm, treasure room and
## board tint come from game/ui/world_theme.gd. Set before the screen is added.
const WorldTheme := preload("res://game/ui/world_theme.gd")
var world_id := WorldTheme.DEFAULT
var DRAGON_TEX: Texture2D
var ARM_TEX: Texture2D
var TREASURE_TEX: Texture2D
var DRAGON_AT := Vector2(716, -34)
var ARM_AT := Vector2(700, 196)
var board_tint := Color(1, 1, 1, 0.9)
var boss_label := "Dragon"


func _load_theme() -> void:
	var th := WorldTheme.get_theme(world_id)
	DRAGON_TEX = load(th["boss_head"])
	ARM_TEX = load(th["boss_arm"])
	TREASURE_TEX = load(th["treasure"])
	DRAGON_AT = th["head_at"]
	ARM_AT = th["arm_at"]
	board_tint = th["board_tint"]
	boss_label = th["boss_label"]


func setup(rng, grade: int, show_debug := false) -> void:
	fight = BounceFight.new(rng, grade)
	var screen_cfg: Dictionary = BounceFight.load_tuning()["screen"]
	slow_mo = float(screen_cfg["last_heart_time_scale"])
	win_gems = int(screen_cfg.get("win_gems", 10))
	debug_on = show_debug


func _ready() -> void:
	_load_theme()
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
		_asked_ms = Time.get_ticks_msec()


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


var _asked_ms := 0


func _on_named(index: int) -> void:
	var shown := PlayLog.boss_shown(fight)
	fight.name_peg(index)
	PlayLog.answer("boss", shown, fight.answer_face, fight.named_face, (Time.get_ticks_msec() - _asked_ms) / 1000.0)
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
		PlayLog.event("boss_won", {"shots": fight.shot_count})
		_say("You win!")
		Beeper.good()
		Ellwynn.boss_beaten()
		await get_tree().create_timer(1.2).timeout
		await _gem_bucket()
		await get_tree().create_timer(1.0).timeout
		done.emit(true)
		return
	if out["state"] == BounceFight.State.LOST:
		phase = "lost"
		PlayLog.event("boss_lost", {"shots": fight.shot_count, "boss_hearts": fight.boss_hearts})
		for d in boss_dice:
			d.visible = false
		Beeper.bad()
		return
	if out["damage"] == 0 and fight.named_right:
		_say("Oh no!")
	_start_naming()


## The dragon's bonus: a bucket of gems drops in from the top, tips over and
## pours them out, and each one counts into the corner. The gems go into the
## save at once (and are written), so leaving early can't lose them.
func _gem_bucket() -> void:
	if not save.is_empty():
		SaveData.add_gems(save, win_gems)
		if persist:
			SaveStore.write(save)
	_say("+%d" % win_gems)
	bucket_t = 0.0
	Beeper.tone(523.0, 0.1)
	var counted := 0
	var end := BUCKET_DROP_S + BUCKET_POUR_S + 0.4
	while bucket_t < end:
		await get_tree().process_frame
		bucket_t += get_process_delta_time()
		var due := clampi(int(floor((bucket_t - BUCKET_DROP_S - 0.5) / (BUCKET_POUR_S / win_gems))) + 1, 0, win_gems)
		while counted < due:
			counted += 1
			gems_shown = counted
			Beeper.tone(1046.0 * pow(1.06, counted - 1), 0.07, -12.0)
	gems_shown = win_gems
	Beeper.good()


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == "lost":
		if Pointer.is_press(event):
			var p := Pointer.local_pos(self, event)
			if fail_buttons.size() == 2 and fail_buttons[0].has_point(p):
				done.emit(false)   # Try: the owner starts the fight again
			elif fail_buttons.size() == 2 and fail_buttons[1].has_point(p):
				to_map = true
				done.emit(false)   # Map: the owner shows the mini map
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


## The boss's hearts sit bottom right, under its dice. The balls left and
## the player's dragon sit left of the board: inside the 4:3 safe area at
## Acorn, further left above Acorn, where the naming column needs the space.
## It ends at SAFE_RIGHT so no heart is cut off on the 5:3 tablet.
func _hearts_panel() -> Rect2:
	return Rect2(744, 452, SAFE_RIGHT - 744, 86)


func _left_x() -> float:
	return 124.0 if fight.auto_name() else 38.0   # the 5:3 tablet shows x 28 and up


func _balls_panel() -> Rect2:
	return Rect2(_left_x(), 40, 100 if fight.auto_name() else 92, 200)


func _hero_feet() -> Vector2:
	return Vector2(_left_x() + 50.0, 532)


func _bubble_rect() -> Rect2:
	return Rect2(SAFE_RIGHT - 160, 300, 160, 42)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.06, 0.04, 0.05))
	# the dragon's hoard: gold and jewels heaped left, right and behind
	draw_texture_rect(TREASURE_TEX, Rect2(0, 0, 960, 540), false)
	Ambient.room(self, TREASURE_TEX.resource_path, _t, _board_rect().grow(8.0))  # the hoard glints, not under the board
	draw_texture_rect(BOARD_TEX, _board_rect(), false, board_tint)
	_draw_claw()   # behind the skull: the arm comes from the body behind it
	_draw_dragon()
	_draw_hero()
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
	if bucket_t >= 0.0:
		_draw_bucket(font)
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
		_draw_aim_line()


## The ball's path from the launcher to the first thing it hits (a wall, a
## bumper, a ±1 peg or a peg that pops; it passes through ghost pegs), in
## dashes, with a ring where it hits.
func _draw_aim_line() -> void:
	var shot_key: int = fight.balls_left * 1000 + fight.live_count()
	if aim != _aim_path_for or shot_key != _aim_path_shot:
		_aim_path_for = aim
		_aim_path_shot = shot_key
		_aim_path = _first_hit_path(aim)
	var col := Color(1, 0.95, 0.6, 0.9)
	var on := true
	var left := DASH
	for k in range(1, _aim_path.size()):
		var a := _aim_path[k - 1]
		var b := _aim_path[k]
		var seg := a.distance_to(b)
		var at := 0.0
		while at < seg:
			var run := minf(left, seg - at)
			var p0 := a.lerp(b, at / seg)
			var p1 := a.lerp(b, (at + run) / seg)
			if on:
				draw_line(p0, p1, col, 5.0)
			at += run
			left -= run
			if left <= 0.0:
				on = not on
				left = DASH if on else DASH_GAP
	if _aim_path.size() > 1:
		var end := _aim_path[_aim_path.size() - 1]
		draw_arc(end, 13.0, 0.0, TAU, 24, col, 4.0)


func _first_hit_path(aim_decideg: int) -> PackedVector2Array:
	var sim = fight.preview_sim(aim_decideg)
	var pts := PackedVector2Array([sim.pos])
	for i in AIM_MAX_STEPS:
		var events: Array = sim.step()
		if i % 3 == 0:
			pts.append(sim.pos)
		var hit := false
		for e in events:
			if e["type"] in ["bounce", "pop", "mod", "end"]:
				hit = true
		if hit:
			pts.append(sim.pos)
			break
	return pts


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
	var size := DRAGON_TEX.get_size() * Look.CHAR_PX
	draw_texture_rect(DRAGON_TEX, Rect2(DRAGON_AT + shake + breathe, size), false, Color(glow, glow, glow))


func _draw_claw() -> void:
	var shake := Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 4.0 * boss_flash
	var size := ARM_TEX.get_size() * Look.CHAR_PX
	var glow := 1.0 + boss_flash * 1.2
	draw_texture_rect(ARM_TEX, Rect2(ARM_AT + shake, size), false, Color(glow, glow, glow))


## The player's robot dragon, facing the board, bobbing gently.
func _draw_hero() -> void:
	var size := hero_tex.get_size()
	var bob := absf(sin(_t * 2.2)) * 3.0
	draw_texture_rect(hero_tex, Rect2(_hero_feet() - Vector2(size.x / 2.0, size.y + bob), size), false)


## The boss's hearts and the balls left, in pixel art on fiery panels.
func _draw_boss(font: Font) -> void:
	# The target, spat out of the jaw as rolled dice (above 12 a numeral).
	if DiceDraw.split_value(fight.target).is_empty():
		DiceDraw.draw_value(self, BOSS_DIE_AT, 80.0, fight.target)
	var hp := _hearts_panel()
	RoundBox.fire(self, hp, _t, 16.0)
	# two rows of hearts, packed a little closer when there are more than 10
	var cols := ceili(fight.boss_max_hearts / 2.0)
	var step := minf(36.0, (hp.size.x - 22.0) / cols)
	var top := hp.position + Vector2(hp.size.x / 2.0 - (cols - 1) * step / 2.0, 46)
	_outlined(font, hp.position + Vector2(0, 23), boss_label, hp.size.x, 20)
	for i in fight.boss_max_hearts:
		var c := top + Vector2((i % cols) * step, (i / cols) * 26)
		draw_texture(HEART_TEX if i < fight.boss_hearts else HEART_EMPTY_TEX, c - Vector2(16, 16))


## The gem bucket (code drawn: a wooden pail with iron hoops, heaped with
## gems) and the gems pouring out of it into the counter at the top.
func _draw_bucket(font: Font) -> void:
	var t := bucket_t
	# it drops in with a bounce, then tips toward the corner
	var drop := clampf(t / BUCKET_DROP_S, 0.0, 1.0)
	var y := lerpf(-120.0, BUCKET_AT.y, 1.0 - pow(1.0 - drop, 3.0)) - 18.0 * sin(clampf((t - BUCKET_DROP_S) / 0.25, 0.0, 1.0) * PI)
	var tip := clampf((t - BUCKET_DROP_S - 0.2) / 0.3, 0.0, 1.0) * 0.55
	var c := Vector2(BUCKET_AT.x, y)
	draw_set_transform(c, tip, Vector2.ONE)
	var body := PackedVector2Array([Vector2(-58, -50), Vector2(58, -50), Vector2(44, 52), Vector2(-44, 52)])
	draw_colored_polygon(body, Color(0.55, 0.33, 0.17))
	for k in 4:
		var x := -40.0 + k * 27.0
		draw_line(Vector2(x, -48), Vector2(x * 0.78, 50), Color(0.38, 0.22, 0.11), 3.0)
	for hy in [-30.0, 30.0]:
		var hw := lerpf(56.0, 46.0, (hy + 50.0) / 100.0)
		draw_line(Vector2(-hw, hy), Vector2(hw, hy), Color(0.3, 0.3, 0.34), 6.0)
	draw_polyline(body + PackedVector2Array([body[0]]), OUTLINE, 4.0)
	draw_arc(Vector2(0, -50), 58.0, PI, TAU, 24, Color(0.3, 0.3, 0.34), 5.0)
	# the heap on top, while it is still full
	var left := win_gems - gems_shown
	for k in mini(left, 9):
		var gx := -44.0 + (k % 5) * 22.0 + (k / 5) * 11.0
		var gy := -60.0 - (k / 5) * 16.0 + 4.0 * sin(_t * 6.0 + k)
		draw_texture_rect(GEM_TEX, Rect2(Vector2(gx, gy) - Vector2(14, 14), Vector2(28, 28)), false)
	draw_set_transform(Vector2.ZERO)
	# the gems in the air: from the lip to the counter, one after another
	var lip := c + Vector2(58, -50).rotated(tip)
	var target := Vector2(560, 40)
	var step := BUCKET_POUR_S / win_gems
	for k in win_gems:
		var u := (t - BUCKET_DROP_S - 0.5 - step * k + 0.5) / 0.5
		if u <= 0.0 or u >= 1.0:
			continue
		var mid := (lip + target) / 2.0 + Vector2(0, -110)
		var p := lip.lerp(mid, u).lerp(mid.lerp(target, u), u)
		var w := absf(cos(u * TAU)) * 26.0 + 4.0
		draw_texture_rect(GEM_TEX, Rect2(p - Vector2(w / 2.0, 15), Vector2(w, 30)), false)
	# the count, big, by the target
	var box := Rect2(target - Vector2(70, 30), Vector2(140, 60))
	RoundBox.fire(self, box, _t, 16.0)
	draw_texture_rect(GEM_TEX, Rect2(box.position + Vector2(10, 12), Vector2(36, 36)), false)
	_outlined(font, box.position + Vector2(44, 42), "+%d" % gems_shown, 90, 32)


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
	var cols := 2
	var top := bp.position + Vector2(bp.size.x / 2.0 - (cols - 1) * 18.0, 64)
	_outlined(ThemeDB.fallback_font, bp.position + Vector2(0, 30), "Balls", bp.size.x, 22)
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
