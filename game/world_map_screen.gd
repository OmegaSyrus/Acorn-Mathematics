## The map (Terrence, 2026-11-07): the worlds on a path, left to right in
## play order (content/worlds.json), at the main menu's Level (Phase 1,
## 2026-11-16: Level N is one pass of all five worlds). Play on the main
## menu opens it, and it follows each area's boss. At its Level a world is
## unlocked when the one before it has been beaten there; the lock comes off
## with a little pop the first time (Lava's too, when a new Level opens). The
## hero stands on the newest unlocked world. Tapping an open world plays it
## (a crossing in progress there picks up again); a locked world shakes its
## lock, and an unlocked world that isn't built yet says "Soon".
## Worlds beaten at this Level get a gold trophy (Phase 6, 2026-11-28: the
## boss's trophy, game/ui/trophy.gd; it was a gold star).
## A Level hero just won (Store.grant_level_rewards, after the boss that
## finished the Level) pops up first: "New hero!" with the hero, tap to go on.
## Under each world's name, six marks (two rows of three), one per level (2026-11-12):
## gold once that level is beaten, with a bright star beside it when its
## crossing was cleared without losing a heart (game/ui/marks.gd). The menu's
## level is framed.
extends Node2D

signal open_world(world: Dictionary)

const AreaFlow := preload("res://logic/path/area_flow.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")
const Marks := preload("res://game/ui/marks.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Content := preload("res://logic/core/content.gd")
const Book := preload("res://logic/core/book.gd")
const Trophy := preload("res://game/ui/trophy.gd")
## The "New hero!" pop: a panel in the middle, tap anywhere to close it.
const POP := Rect2(300, 110, 360, 330)
const EllwynnRef := preload("res://game/ellwynn.gd")
const Pointer := preload("res://game/ui/pointer.gd")
## The "Level N" title: a tap says the prompt again.
const TITLE_RECT := Rect2(300, 56, 360, 72)
## One level's mark and star, left to right, six to a world in two rows of
## three (levels 1-3 over 4-6), so the edge worlds stay inside the 4:3 band.
const MARK_STEP := 30
const ROW_STEP := 18
const PER_ROW := 3
const LEVELS := 6

## Node middles, inside the 4:3 band (x 120..840) a tablet shows.
const XS := [180.0, 330.0, 480.0, 630.0, 780.0]
const YS := [330.0, 260.0, 330.0, 260.0, 330.0]
const R := 52.0
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const LOCKED := Color(0.32, 0.3, 0.33)
const GOLD := Color(1.0, 0.8, 0.2)
const SHAKE_S := 0.45

var save: Dictionary
var worlds: Array = []
var choice: ChoiceWidget
var _t := 0.0
var _shake := {}  # world index -> seconds left
var fresh_unlock := -1  # a world whose lock just came off (pops on show), -1 = none
var _unlock := 0.0      # 0..1 the lock popping off
var level := 1          # the main menu's level number, framed in each row of marks
var _ids := {}          # world id -> its level ids by number (Content.level_ids)
var new_heroes: Array = []  # Level heroes just won, shown one by one before the map
var _pop_hero := ""         # the hero in the pop now, "" for none
var _pop := 0.0             # 0..1 the pop growing in
## What Ellwynn says first, after a boss (Ellwynn.after_boss_lines): [[cue, take]],
## each after the one before is done, then "Pick a world!" (P1).
var lines: Array = []
var _picked := false


func setup(profile: Dictionary, world_list: Array, just_unlocked := -1, menu_level := 1, heroes := []) -> void:
	save = profile
	new_heroes = heroes
	worlds = world_list.slice(0, XS.size())
	fresh_unlock = just_unlocked
	level = clampi(menu_level, 1, LEVELS)
	for w in worlds:
		_ids[String(w["id"])] = Content.level_ids(String(w["id"]), LEVELS)


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for i in worlds.size():
		rects.append(node_rect(i))
	var here := _hero_at()
	for id in new_heroes:
		await _show_new_hero(String(id))
	if fresh_unlock >= 0:
		await get_tree().create_timer(0.5).timeout
		Beeper.good()
		await create_tween().tween_property(self, "_unlock", 1.0, 0.8).finished
	_speak()
	while true:
		choice.present(rects, here)
		var i: int = await choice.picked
		var ell := EllwynnRef.here(self)
		if _open(i):
			_picked = true
			Beeper.good()
			open_world.emit(worlds[i])
			return
		Beeper.bad()
		_shake[i] = SHAKE_S
		if ell != null and not _unlocked(i):
			ell.prompt("P2")  # locked: beat the one before it first


## After a boss, her lines in turn (L1 to L5), then the prompt (P1). Each
## waits for the one before (the menu's "Let's go!" too), and stops once a
## world is picked or the map is gone.
func _speak() -> void:
	var ell := EllwynnRef.here(self)
	if ell == null:
		return
	for l in lines:
		await ell.wait_quiet(4.0)
		if _picked or not is_inside_tree():
			return
		if int(l[1]) > 0:
			ell.cue_take(String(l[0]), int(l[1]))
		else:
			ell.cue_play(String(l[0]))
	await ell.wait_quiet(4.0)
	if _picked or not is_inside_tree():
		return
	ell.prompt("P1")


func _unhandled_input(event: InputEvent) -> void:
	if Pointer.is_press(event) and TITLE_RECT.has_point(Pointer.local_pos(self, event)):
		var ell := EllwynnRef.here(self)
		if ell != null and ell.replay_prompt():
			get_viewport().set_input_as_handled()


## "New hero!": the hero grows in on a panel with a chime and sparkles;
## a tap anywhere (after the usual lockout) closes it.
func _show_new_hero(id: String) -> void:
	_pop_hero = id
	_pop = 0.0
	await get_tree().create_timer(0.3).timeout
	Beeper.good()
	Beeper.gems(4)
	create_tween().tween_property(self, "_pop", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	choice.show_highlight = false
	choice.present([Rect2(-480, -100, 1920, 740)])
	await choice.picked
	choice.show_highlight = true
	Beeper.tone(660.0, 0.08)
	_pop_hero = ""


## The tap area of world i (the circle and its name).
func node_rect(i: int) -> Rect2:
	return Rect2(XS[i] - R - 14, YS[i] - R - 14, (R + 14) * 2, (R + 14) * 2 + 60)


func _open(i: int) -> bool:
	return AreaFlow.world_open(save, worlds, i, level)


func _unlocked(i: int) -> bool:
	return AreaFlow.world_unlocked(save, worlds, i, level)


## The hero stands on the last open world.
func _hero_at() -> int:
	var at := 0
	for i in worlds.size():
		if _open(i):
			at = i
	return at


func _process(delta: float) -> void:
	_t += delta
	for k in _shake.keys():
		_shake[k] -= delta
		if _shake[k] <= 0.0:
			_shake.erase(k)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.08, 0.12))
	_label(font, Vector2(120, 110), 720, "Level %d" % level, 56, Color(1.0, 0.7, 0.3))
	# the path: dots between the worlds, gold up to the hero
	var here := _hero_at()
	for i in worlds.size() - 1:
		var a := Vector2(XS[i], YS[i])
		var b := Vector2(XS[i + 1], YS[i + 1])
		var n := 6
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			draw_circle(p, 6.0, GOLD if i < here else Color(0.45, 0.42, 0.45))
	for i in worlds.size():
		_draw_world(font, i)
	var tex := Look.hero_texture()
	var foot := Vector2(XS[here], YS[here] - R * 0.35 + sin(_t * 3.0) * 3.0)
	draw_texture(tex, (foot - Vector2(tex.get_width() / 2.0, tex.get_height())).round())
	if _pop_hero != "":
		_draw_new_hero(font)


## The pop: dims the map, a panel with "New hero!", the hero at 1:1 on a
## glow with stars turning round it.
func _draw_new_hero(font: Font) -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.6 * _pop))
	var s := maxf(_pop, 0.01)
	var c := POP.get_center()
	draw_set_transform(c, 0.0, Vector2(s, s))
	var r := Rect2(-POP.size / 2.0, POP.size)
	RoundBox.fill(self, r, Color(0.16, 0.11, 0.1), 24.0)
	RoundBox.frame(self, r, GOLD, 4.0, 24.0)
	_label(font, Vector2(r.position.x, r.position.y + 62), r.size.x, "New hero!", 46, GOLD)
	var feet := Vector2(0, r.end.y - 50)
	draw_circle(feet + Vector2(0, -60), 82.0, Color(1.0, 0.85, 0.4, 0.18))
	for k in 6:
		var a := _t * 1.2 + TAU * k / 6.0
		_draw_star(feet + Vector2(0, -60) + Vector2(cos(a), sin(a)) * 104.0, 10.0)
	draw_set_transform(Vector2.ZERO)
	if _pop < 0.98:
		return
	# the hero at 1:1 (never scaled, Look.CHAR_PX), once the panel is full size
	var tex := Look.hero_texture(_pop_hero)
	var bob := absf(sin(_t * 3.0)) * 4.0
	var at := c + feet - Vector2(tex.get_width() / 2.0, tex.get_height() + bob)
	draw_set_transform(c + feet + Vector2(0, -2), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_texture(tex, at.round())


func _draw_world(font: Font, i: int) -> void:
	var w: Dictionary = worlds[i]
	var open := _unlocked(i)
	var popping := i == fresh_unlock and _unlock < 1.0
	var c := Vector2(XS[i], YS[i])
	if _shake.has(i):
		c.x += sin(_shake[i] * 60.0) * 6.0 * (_shake[i] / SHAKE_S)
	var col := LOCKED
	if open:
		var rgb: Array = w.get("color", [0.8, 0.6, 0.4])
		col = Color(rgb[0], rgb[1], rgb[2])
	draw_circle(c, R + 5, DARK)
	draw_circle(c, R, col)
	draw_circle(c + Vector2(-R * 0.3, -R * 0.3), R * 0.28, Color(1, 1, 1, 0.25))
	if not open:
		_draw_lock(c)
	elif popping:
		# the lock lifts off and fades the first time the world is unlocked
		_draw_lock(c + Vector2(0, -_unlock * 70.0), 1.0 - _unlock)
	elif Book.trophy_at(save, String(w["id"]), level):
		# the boss's trophy, by the world's lower right
		Trophy.draw(self, c + Vector2(R * 0.74, R * 0.58) - Trophy.size(3) / 2.0, true, 3)
	# the name under the circle, a word per line
	var words: PackedStringArray = String(w["name"]).split(" ")
	if words.size() == 2 and words[0].length() <= 3:
		words = PackedStringArray([w["name"]])
	for k in words.size():
		_label(font, Vector2(c.x - 90, c.y + R + 32 + k * 28), 180, words[k], 26,
				INK if open else Color(0.62, 0.6, 0.62))
	if open and not w.has("area") and not popping:
		_label(font, Vector2(c.x - 60, c.y + 9), 120, "Soon", 26, INK)
	if w.has("area"):
		_draw_marks(String(w["id"]), Vector2(c.x, c.y + R + 32 + (words.size() - 1) * 28 + 14))


## The six level marks of a world, centered under its name (top at `top`).
func _draw_marks(world_id: String, top: Vector2) -> void:
	var ids: Array = _ids.get(world_id, [])
	var x0 := roundf(top.x - (MARK_STEP * (PER_ROW - 1) + Marks.pair_width()) / 2.0)
	for n in ids.size():
		var at := Vector2(x0 + (n % PER_ROW) * MARK_STEP, top.y + (n / PER_ROW) * ROW_STEP)
		var id: int = ids[n]
		if n + 1 == level:
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(Marks.SIZE + 4, Marks.SIZE + 4)), INK)
		Marks.draw_pair(self, at, id > 0 and SaveData.has_mark(save, world_id, id),
				id > 0 and SaveData.has_star(save, world_id, id))


## A padlock: a dark body and a shackle over it.
func _draw_lock(c: Vector2, a := 1.0) -> void:
	draw_arc(c + Vector2(0, -6), 14.0, PI, TAU, 16, Color(DARK, a), 7.0)
	RoundBox.fill(self, Rect2(c + Vector2(-20, -6), Vector2(40, 30)), Color(DARK, a), 6.0)
	draw_circle(c + Vector2(0, 7), 4.0, Color(LOCKED, a))


func _draw_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_colored_polygon(pts, GOLD)
	draw_polyline(outline, DARK, 3.0)


func _label(font: Font, at: Vector2, w: float, text: String, size: int, col: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 7, DARK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
