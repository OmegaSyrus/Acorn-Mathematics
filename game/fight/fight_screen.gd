## The fight graybox: one monster fight (or the miniboss duel) with
## placeholder shapes. Drives Fight (all rules live there) and only animates
## what it returns. Covers the area screen while it runs; drawn in the
## 960x540 design space with everything that matters inside x 120..840.
##
## The monster is its sprite where one exists (mirrored to face the hero),
## else a labelled box; either way the label shows which reaction it is
## playing (Monsters.STATES), so each state can be checked before art exists.
extends Node2D

signal done(won: bool)

const Fight := preload("res://logic/fight/fight.gd")
const Duel := preload("res://logic/fight/duel.gd")
const Attack := preload("res://logic/fight/attack.gd")
const Monsters := preload("res://logic/fight/monsters.gd")
const DieView := preload("res://game/ui/die_view.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

const HERO_POS := Vector2(250, 372)
const MONSTER_POS := Vector2(690, 372)
const MONSTER_SIZE := Vector2(150, 170)
const DICE_Y := 128.0
const SHIELD_Y := 455.0
const SHIELD_SIZE := Vector2(136, 118)
const SHIELD_GAP := 160.0

const INK := Color(0.96, 0.94, 0.9)
## Monster art and the scale it is drawn at.
const MONSTER_ART := {
	"blorp": ["res://art/lava/blorp-idle.png", 0.95],
	"craggy": ["res://art/lava/craggy.png", 1.0],
	"surtling": ["res://art/lava/surtling.png", 1.4],
	"mimic": ["res://art/lava/mimic.png", 1.4],
	"lava_miniboss": ["res://art/lava/surtling-chief.png", 1.05],
}
## The hero: the robot dragon, facing the monster on the right.
const HERO_TEX := preload("res://art/lava/robodragon.png")
const HERO_ART_SCALE := 1.5
const HEART_TEX := preload("res://art/ui/heart.png")
const HEART_EMPTY_TEX := preload("res://art/ui/heart-empty.png")
const SHIELD_TEX := preload("res://art/ui/shield.png")
const SHIELD_ART_SCALE := 1.2
const NAME_RIGHT := 842.0   # the name box hugs the right edge of the safe area
const NAME_Y := 58.0
const MONSTER_COLORS := {
	"blorp": Color(0.85, 0.35, 0.12),
	"craggy": Color(0.5, 0.48, 0.45),
	"mimic": Color(0.55, 0.33, 0.12),
	"lava_miniboss": Color(0.55, 0.12, 0.35),
}

var fight
var is_duel := false
var debug_on := false

var dice: Array = []
var choice: ChoiceWidget
var shields_shown := false
var picked := -1
var revealed := false
var monster_state := "idle"
var monster_dx := 0.0
var monster_flash := 0.0
var monster_sink := 0.0
var hero_dx := 0.0
var hero_flash := 0.0
var hero_sink := 0.0
var clang := 0.0
var bubble := ""
var monster_tex: Texture2D
var monster_scale := 1.0
var _t := 0.0


## first_strike: a mimic whose lock was answered right starts one heart down.
## duel: the miniboss duel (numerals, restarts itself on a loss).
func setup(rng, grade: int, monster_id: String, first_strike := false, duel := false, show_debug := false) -> void:
	is_duel = duel
	debug_on = show_debug
	if duel:
		fight = Duel.new(rng, grade, monster_id, Monsters.hearts_of(monster_id))
	else:
		fight = Fight.new(rng, grade, monster_id, Monsters.hearts_of(monster_id), first_strike)


func _ready() -> void:
	z_index = 5
	for i in 2:
		var d := DieView.new()
		d.visible = false
		add_child(d)
		d.pip_tapped.connect(_on_pip_tapped)
		dice.append(d)
	choice = ChoiceWidget.new()
	add_child(choice)
	if MONSTER_ART.has(fight.monster_id):
		monster_tex = load(MONSTER_ART[fight.monster_id][0])
		monster_scale = MONSTER_ART[fight.monster_id][1]
	_loop()


# --- the exchange loop -----------------------------------------------------

func _loop() -> void:
	_say(Monsters.name_of(fight.monster_id))
	await _wait(0.8)
	while true:
		await _wind_up()
		choice.present(_shield_rects())
		var pick: int = await choice.picked
		picked = pick
		var out: Dictionary = fight.choose(pick)
		revealed = true
		for d in dice:
			if d.visible:
				d.show_numeral()
		_say(str(out["answer"]))
		if out["right"]:
			await _parry()
		else:
			await _hit()
		if out["state"] == Fight.State.WON:
			await _monster_collapse()
			done.emit(true)
			return
		if out["state"] == Fight.State.LOST:
			await _hero_collapse()
			if fight.on_loss == Fight.OnLoss.RESTART_DUEL:
				_say("Again!")
				await _wait(0.8)
				_reset_looks()
				fight.restart()
				continue
			done.emit(false)
			return
		fight.next_exchange()


## The monster winds up and its dice tumble in. It holds the wind-up, with
## no timer, until the child picks.
func _wind_up() -> void:
	shields_shown = false
	picked = -1
	revealed = false
	monster_state = "wind_up"
	await _tween_prop("monster_dx", -18.0, 0.25)
	var atk = fight.attack
	var xs := _dice_xs(atk)
	for i in dice.size():
		var d: DieView = dice[i]
		d.visible = i < atk.dice.size()
		if not d.visible:
			continue
		d.slip = atk.kind == Attack.Kind.MOVE_AND_SLIP and i == 1
		d.position = Vector2(xs[i], DICE_Y)
		d.roll_to(atk.dice[i], 0.12 * i)
	Beeper.roll()
	while true:
		await get_tree().process_frame
		var all_on := true
		for i in atk.dice.size():
			all_on = all_on and dice[i].face_on
		if all_on:
			break
	for i in atk.dice.size():
		dice[i].countable = true
	monster_state = "idle"
	shields_shown = true
	_say("Block!")


## Right answer: the shield clangs, the hero strikes back, the monster loses a heart.
func _parry() -> void:
	monster_state = "strike"
	await _tween_prop("monster_dx", -120.0, 0.18)
	monster_state = "blocked"
	clang = 1.0
	Beeper.tone(1200.0, 0.08)
	create_tween().tween_property(self, "clang", 0.0, 0.4)
	await _tween_prop("monster_dx", 0.0, 0.2)
	await _tween_prop("hero_dx", 230.0, 0.16)
	monster_state = "hurt"
	monster_flash = 1.0
	Beeper.good()
	create_tween().tween_property(self, "monster_flash", 0.0, 0.5)
	await _tween_prop("hero_dx", 0.0, 0.25)
	await _wait(0.35)
	monster_state = "idle"


## Wrong answer: the swing lands and the hero loses a heart.
func _hit() -> void:
	monster_state = "strike"
	await _tween_prop("monster_dx", -260.0, 0.18)
	hero_flash = 1.0
	Beeper.bad()
	create_tween().tween_property(self, "hero_flash", 0.0, 0.5)
	await _tween_prop("hero_dx", -40.0, 0.1)
	await _tween_prop("monster_dx", 0.0, 0.25)
	await _tween_prop("hero_dx", 0.0, 0.2)
	await _wait(0.35)
	monster_state = "idle"


func _monster_collapse() -> void:
	shields_shown = false
	monster_state = "collapse"
	await _tween_prop("monster_sink", 1.0, 0.8)
	_say("Yes!")
	Beeper.good()
	await _wait(1.0)


func _hero_collapse() -> void:
	shields_shown = false
	monster_state = "gloat"
	_say("Oops!")
	await _tween_prop("hero_sink", 1.0, 0.7)
	await _wait(0.6)


func _reset_looks() -> void:
	monster_sink = 0.0
	hero_sink = 0.0
	monster_state = "idle"


func _say(text: String) -> void:
	bubble = text


func _on_pip_tapped(count: int) -> void:
	Beeper.count(count)
	_say(str(count))


func _tween_prop(prop: String, to: float, dur: float) -> void:
	await create_tween().tween_property(self, prop, to, dur).finished


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("debug"):
		debug_on = not debug_on
	queue_redraw()


# --- layout ----------------------------------------------------------------

func _shield_rects() -> Array:
	var out := []
	for i in 4:
		var cx := 480.0 + (i - 1.5) * SHIELD_GAP
		out.append(Rect2(Vector2(cx, SHIELD_Y) - SHIELD_SIZE / 2.0, SHIELD_SIZE))
	return out


## Where the attack dice sit. Sapling leaves room for "+ ? =" and the target.
func _dice_xs(atk) -> Array:
	if atk.kind == Attack.Kind.DIE_AND_TARGET:
		return [200.0]
	if atk.dice.size() == 2:
		return [400.0, 560.0]
	return [480.0]


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.12, 0.07, 0.06))
	draw_rect(Rect2(-480, 380, 1920, 260), Color(0.2, 0.12, 0.09))
	_draw_hearts(Vector2(140, 30), fight.hero_hearts, 3)
	_draw_hearts(Vector2(824 - 36 * (fight.monster_max_hearts - 1), 30), fight.monster_hearts, fight.monster_max_hearts)
	# the enemy's name in a fiery box, top right under its hearts
	var name := Monsters.name_of(fight.monster_id)
	var w := maxf(160.0, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 36.0)
	var box := Rect2(NAME_RIGHT - w, NAME_Y, w, 40)
	RoundBox.fire(self, box, _t, 14.0)
	_outlined(font, box.position + Vector2(0, 29), name, box.size.x, 24)
	_draw_target(font)
	_draw_hero(HERO_POS + Vector2(hero_dx, hero_sink * 90.0))
	_draw_monster(font)
	if shields_shown or revealed:
		_draw_shields(font)
	if bubble != "":
		var b := Rect2(380, 12, 200, 44)
		RoundBox.fire(self, b, _t, 16.0)
		_outlined(font, b.position + Vector2(0, 32), bubble, b.size.x, 28)
	if debug_on:
		var atk = fight.attack
		var line := "dice %s target %d answer %d choices %s  hearts %d/%d" % [str(atk.dice), atk.target, atk.answer,
				str(atk.choices), fight.hero_hearts, fight.monster_hearts]
		draw_rect(Rect2(124, 186, 712, 20), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(128, 201), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.6))


## Sprout and Oak: the coloured sign between the two dice. Sapling: the die,
## then "+ ? =", then the target as dots.
func _draw_target(font: Font) -> void:
	var atk = fight.attack
	if not dice[0].visible or not dice[0].face_on:
		return
	if atk.dice.size() == 2 and dice[1].face_on:
		var op := "-" if atk.kind == Attack.Kind.MOVE_AND_SLIP else "+"
		DiceDraw.draw_op(self, Vector2(480, DICE_Y), op, 40.0, _t)
	if atk.kind != Attack.Kind.DIE_AND_TARGET:
		return
	DiceDraw.draw_op(self, Vector2(282, DICE_Y), "+", 32.0, _t)
	var q := Rect2(312, DICE_Y - 34, 68, 68)
	RoundBox.fill(self, q, Color(0.25, 0.2, 0.18))
	RoundBox.frame(self, q, INK, 2.0)
	draw_string(font, q.position + Vector2(0, 50), "?", HORIZONTAL_ALIGNMENT_CENTER, q.size.x, 44, INK)
	draw_string(font, Vector2(388, DICE_Y + 16), "=", HORIZONTAL_ALIGNMENT_CENTER, 40, 40, INK)
	DiceDraw.draw_value(self, Vector2(492, DICE_Y), 56.0, atk.target)


func _draw_shields(font: Font) -> void:
	var rects := _shield_rects()
	var atk = fight.attack
	var size := SHIELD_TEX.get_size() * SHIELD_ART_SCALE
	for i in rects.size():
		var r: Rect2 = rects[i]
		var tint := Color.WHITE
		if revealed and i == atk.answer_index:
			tint = Color(1.25, 1.05, 0.45)
		elif revealed and i == picked:
			tint = Color(0.75, 0.4, 0.38)
		if clang > 0.0 and i == picked:
			tint = tint.lerp(Color(2.0, 2.0, 2.0), clang)
		var art := Rect2(r.get_center() - size / 2.0, size)
		draw_texture_rect(SHIELD_TEX, art, false, tint)
		# the numeral or dots sit on the wooden face, a little above center
		var c := art.get_center() + Vector2(0, -10)
		var v: int = atk.choices[i]
		if fight.choice_style == Fight.ChoiceStyle.NUMERALS:
			draw_string_outline(font, c + Vector2(-60, 22), str(v), HORIZONTAL_ALIGNMENT_CENTER, 120, 60, 6, Color(1, 0.95, 0.85))
			draw_string(font, c + Vector2(-60, 22), str(v), HORIZONTAL_ALIGNMENT_CENTER, 120, 60, Color(0.08, 0.06, 0.05))
		else:
			DiceDraw.draw_value(self, c, 44.0 if v <= 6 else 36.0, v)


## Light text with a dark outline, for the fiery boxes.
func _outlined(font: Font, pos: Vector2, text: String, width: float, size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 7, Color(0.08, 0.03, 0.03))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, INK)


## Pixel hearts at 32 px, full then empty.
func _draw_hearts(at: Vector2, have: int, total: int) -> void:
	for i in total:
		var c := at + Vector2(36 * i, 0)
		draw_texture(HEART_TEX if i < have else HEART_EMPTY_TEX, c - Vector2(16, 16))


## The robot dragon: it breathes while idle, flashes red when hit and
## squashes down when it collapses.
func _draw_hero(base: Vector2) -> void:
	var alpha := 1.0 - hero_sink * 0.7
	var tint := Color.WHITE.lerp(Color(1.6, 0.5, 0.5), hero_flash)
	tint.a = alpha
	var breathe := sin(_t * 2.4) * 0.02
	var size := HERO_TEX.get_size() * HERO_ART_SCALE * Vector2(1.0 + hero_sink * 0.3, (1.0 + breathe) * (1.0 - hero_sink * 0.5))
	var feet := base + Vector2(0, 12)
	draw_texture_rect(HERO_TEX, Rect2(feet - Vector2(size.x / 2.0, size.y), size), false, tint)
	# the hero's shield, raised while the child decides
	if shields_shown and not revealed:
		draw_texture_rect(SHIELD_TEX, Rect2(base + Vector2(52, -100), SHIELD_TEX.get_size() * 0.55), false)


func _draw_monster(font: Font) -> void:
	var base_col: Color = MONSTER_COLORS.get(fight.monster_id, Color(0.6, 0.2, 0.2))
	var col := base_col.lerp(Color.WHITE, monster_flash * 0.8)
	col.a = 1.0 - monster_sink * 0.8
	var breathe := sin(_t * 2.2) * 4.0 if monster_state == "idle" else 0.0
	var size := MONSTER_SIZE * Vector2(1.0 + monster_sink * 0.3, 1.0 - monster_sink * 0.7)
	var c := MONSTER_POS + Vector2(monster_dx, monster_sink * 60.0 - breathe)
	var r := Rect2(c - Vector2(size.x / 2.0, size.y), size)
	if monster_tex != null:
		# the art faces right; a negative width mirrors it to face the hero
		var ts := monster_tex.get_size() * monster_scale * Vector2(1.0 + monster_sink * 0.3, 1.0 - monster_sink * 0.7)
		var tr := Rect2(c + Vector2(ts.x / 2.0, -ts.y + 12.0), Vector2(-ts.x, ts.y))
		var glow := 1.0 + monster_flash * 2.0
		draw_texture_rect(monster_tex, tr, false, Color(glow, glow, glow, col.a))
		if debug_on:
			draw_string(font, Vector2(c.x - 100, c.y - ts.y + 44), monster_state, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color(INK, col.a))
		return
	RoundBox.fill(self, r, col, 18.0)
	RoundBox.frame(self, r, Color(0.1, 0.05, 0.05, col.a), 3.0, 18.0)
	if fight.monster_id == "mimic":
		# a chest with teeth: the lid line and a row of fangs
		draw_line(r.position + Vector2(0, size.y * 0.35), r.position + Vector2(size.x, size.y * 0.35), Color(0.2, 0.1, 0.05, col.a), 4.0)
		for k in 5:
			var tx := r.position.x + 18 + k * (size.x - 36) / 4.0
			var ty := r.position.y + size.y * 0.35
			draw_colored_polygon(PackedVector2Array([Vector2(tx - 8, ty), Vector2(tx + 8, ty), Vector2(tx, ty + 16)]), Color(1, 1, 0.9, col.a))
	# angry eyes, looking at the hero
	var eye_y := r.position.y + size.y * 0.22
	for ex in [-30.0, 30.0]:
		var e := Vector2(c.x + ex, eye_y)
		draw_circle(e, 12.0, Color(1, 0.95, 0.6, col.a))
		draw_circle(e + Vector2(-4, 2), 5.0, Color(0, 0, 0, col.a))
		draw_line(e + Vector2(-16, -16 if ex < 0 else -8), e + Vector2(16, -8 if ex < 0 else -16), Color(0.1, 0, 0, col.a), 4.0)
	# the placeholder label: who it is and which reaction is playing
	draw_string(font, Vector2(r.position.x - 25, r.position.y - 8), monster_state, HORIZONTAL_ALIGNMENT_CENTER, size.x + 50, 18, Color(INK, col.a))
