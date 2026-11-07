## The map (Terrence, 2026-11-07): the worlds on a path, left to right in
## play order (content/worlds.json). Play on the main menu opens it, and it
## follows each area's boss. A world is unlocked when the one before it has
## been beaten; the lock comes off with a little pop the first time. The
## hero stands on the newest unlocked world. Tapping an open world plays it
## (a crossing in progress there picks up again); a locked world shakes its
## lock, and an unlocked world that isn't built yet says "Soon".
## Beaten worlds get a gold star.
extends Node2D

signal open_world(world: Dictionary)

const AreaFlow := preload("res://logic/path/area_flow.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")

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


func setup(profile: Dictionary, world_list: Array, just_unlocked := -1) -> void:
	save = profile
	worlds = world_list.slice(0, XS.size())
	fresh_unlock = just_unlocked


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for i in worlds.size():
		rects.append(node_rect(i))
	var here := _hero_at()
	if fresh_unlock >= 0:
		await get_tree().create_timer(0.5).timeout
		Beeper.good()
		await create_tween().tween_property(self, "_unlock", 1.0, 0.8).finished
	while true:
		choice.present(rects, here)
		var i: int = await choice.picked
		if _open(i):
			Beeper.good()
			open_world.emit(worlds[i])
			return
		Beeper.bad()
		_shake[i] = SHAKE_S


## The tap area of world i (the circle and its name).
func node_rect(i: int) -> Rect2:
	return Rect2(XS[i] - R - 14, YS[i] - R - 14, (R + 14) * 2, (R + 14) * 2 + 60)


func _open(i: int) -> bool:
	return AreaFlow.world_open(save, worlds, i)


func _unlocked(i: int) -> bool:
	return AreaFlow.world_unlocked(save, worlds, i)


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
	_label(font, Vector2(120, 110), 720, "Map", 56, Color(1.0, 0.7, 0.3))
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
	elif AreaFlow.world_beaten(save, w["id"]):
		_draw_star(c + Vector2(R * 0.78, R * 0.62), 20.0)
	# the name under the circle, a word per line
	var words: PackedStringArray = String(w["name"]).split(" ")
	if words.size() == 2 and words[0].length() <= 3:
		words = PackedStringArray([w["name"]])
	for k in words.size():
		_label(font, Vector2(c.x - 90, c.y + R + 32 + k * 28), 180, words[k], 26,
				INK if open else Color(0.62, 0.6, 0.62))
	if open and not w.has("area") and not popping:
		_label(font, Vector2(c.x - 60, c.y + 9), 120, "Soon", 26, INK)


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
