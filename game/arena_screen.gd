## The Arena's screen between fights (Phase 6, 2026-11-28): the round's
## monsters in a row (beaten ones dimmed with a tick, the next one framed in
## gold and lifted), the hero's hearts, and a big Go. After the last fight
## it shows the gems won; after a loss, Try (the round again from fight 1)
## and Back. Rules live in logic/modes/arena_run.gd; main.gd (through
## game/modes_flow.gd) plays the fights. Short words only.
extends Node2D

## Go: the next fight (or, after a win, a new round). Try comes here too.
signal go
signal back

const ArenaRun := preload("res://logic/modes/arena_run.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const WorldTheme := preload("res://game/ui/world_theme.gd")
const MenuScene := preload("res://game/ui/menu_scene.gd")
const HEART_TEX := preload("res://art/ui/heart.png")
const HEART_EMPTY_TEX := preload("res://art/ui/heart-empty.png")
const GEM_TEX := preload("res://art/lava/gem.png")

const BACK_RECT := Rect2(128, 12, 124, 72)
const GO_RECT := Rect2(380, 392, 200, 120)
## After a loss: Try in Go's place.
const SLOT := Vector2(132, 210)
const SLOT_GAP := 8.0
const ROW_Y := 132.0
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1.0, 0.82, 0.35)
const GREEN := Color(0.2, 0.62, 0.3)
const TITLE_EDGE := Color(0.2, 0.1, 0.05)

var run: ArenaRun
## The gems the round just paid (shown after a win), 0 otherwise.
var paid := 0
var choice: ChoiceWidget
var _tex := {}
var _t := 0.0


func setup(arena: ArenaRun, gems_paid := 0) -> void:
	run = arena
	paid = gems_paid


func _ready() -> void:
	add_child(MenuScene.new())
	for id in run.monsters:
		if not _tex.has(id):
			_tex[id] = WorldTheme.monster_texture(id)
	choice = ChoiceWidget.new()
	add_child(choice)
	choice.present([GO_RECT, BACK_RECT], 0)
	var i: int = await choice.picked
	if i == 0:
		Beeper.good()
		go.emit()
	else:
		Beeper.tone(440.0, 0.08)
		back.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func slot_rect(i: int) -> Rect2:
	var n := run.monsters.size()
	var w := n * SLOT.x + (n - 1) * SLOT_GAP
	var x0 := roundf(480.0 - w / 2.0)
	return Rect2(x0 + i * (SLOT.x + SLOT_GAP), ROW_Y, SLOT.x, SLOT.y)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.06, 0.03, 0.05, 0.55))
	_outlined(font, Vector2(120, 68), "Arena", 720, 52)
	_draw_hearts(font)
	for i in run.monsters.size():
		_draw_slot(i)
	# the buttons
	var go_label := "Go"
	if run.phase == ArenaRun.LOST:
		go_label = "Try"
	RoundBox.fill(self, GO_RECT, GREEN, 18.0)
	RoundBox.frame(self, GO_RECT, GOLD, 3.0, 18.0)
	draw_string(font, GO_RECT.position + Vector2(0, GO_RECT.size.y / 2 + 18), go_label, HORIZONTAL_ALIGNMENT_CENTER,
			GO_RECT.size.x, 52, INK)
	RoundBox.fill(self, BACK_RECT, Color(0.42, 0.36, 0.33), 14.0)
	draw_string(font, BACK_RECT.position + Vector2(0, 47), "Back", HORIZONTAL_ALIGNMENT_CENTER, BACK_RECT.size.x, 30, INK)
	if run.phase == ArenaRun.WON:
		_draw_win(font)


## The hero's hearts, top right: full ones left, empty ones for those lost.
func _draw_hearts(_font: Font) -> void:
	var at := Vector2(744, 48)
	for i in ArenaRun.HERO_HEARTS:
		draw_texture(HEART_TEX if i < run.hearts else HEART_EMPTY_TEX, at + Vector2(36 * i, 0) - Vector2(16, 16))


## One monster of the round: its card, the monster at 1:1 (cropped to the
## card, never scaled), dimmed with a tick once beaten, framed in gold and
## bobbing when it is next.
func _draw_slot(i: int) -> void:
	var r := slot_rect(i)
	var next := run.phase == ArenaRun.READY and i == run.at
	var beaten := i < run.at or run.phase == ArenaRun.WON
	if next:
		r.position.y -= roundf(6.0 + 4.0 * sin(_t * 4.0))
	RoundBox.fill(self, r, Color(0.16, 0.11, 0.1, 0.9) if not next else Color(0.36, 0.22, 0.12, 0.95), 14.0)
	var tex: Texture2D = _tex.get(run.monsters[i])
	if tex != null:
		var w := minf(tex.get_width(), r.size.x - 8)
		var h := minf(tex.get_height(), r.size.y - 16)
		var src := Rect2(roundf((tex.get_width() - w) / 2.0), tex.get_height() - h, w, h)
		var dst := Rect2(Vector2(roundf(r.get_center().x - w / 2.0), r.end.y - 8 - h), Vector2(w, h))
		var tint := Color(1, 1, 1) if not beaten else Color(0.45, 0.45, 0.45)
		draw_texture_rect_region(tex, dst, src, tint)
	if beaten:
		var c := r.get_center()
		draw_polyline(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(-8, 20), c + Vector2(28, -22)]), DARK, 16.0)
		draw_polyline(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(-8, 20), c + Vector2(28, -22)]), GREEN.lightened(0.3), 9.0)
	if next:
		RoundBox.frame(self, r, GOLD, 4.0, 14.0)
	elif run.phase == ArenaRun.LOST and i == run.at:
		RoundBox.frame(self, r, Color(0.8, 0.25, 0.2), 4.0, 14.0)


## The round won: "Win!" and the gems it paid.
func _draw_win(font: Font) -> void:
	var box := Rect2(600, 392, 220, 120)
	RoundBox.fill(self, box, Color(0.46, 0.28, 0.6), 18.0)
	RoundBox.frame(self, box, GOLD, 3.0, 18.0)
	draw_string(font, box.position + Vector2(0, 46), "Win!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 38, INK)
	if paid > 0:
		var gem_at := box.position + Vector2(box.size.x / 2.0 - 58, 58)
		draw_texture_rect(GEM_TEX, Rect2(gem_at, Vector2(48, 48)), false)
		draw_string(font, gem_at + Vector2(54, 38), "+%d" % paid, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.86, 0.5))


func _outlined(font: Font, pos: Vector2, text: String, width: float, size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 12, TITLE_EDGE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(1.0, 0.6, 0.25))
