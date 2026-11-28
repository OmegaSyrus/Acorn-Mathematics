## Bounce's picker (Phase 6, 2026-11-28): a card for each boss already
## beaten (Book.bosses_beaten), with the boss's face and its world's name.
## A tap on a card plays that boss's board again at the child's Level
## (game/modes_flow.gd); Back goes to the main menu. The faces are the boss
## art at 1:1, cropped round the face (characters are never scaled).
extends Node2D

signal picked(world_id: String)
signal back

const Modes := preload("res://logic/modes/modes.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const WorldTheme := preload("res://game/ui/world_theme.gd")
const MenuScene := preload("res://game/ui/menu_scene.gd")

const BACK_RECT := Rect2(128, 12, 124, 72)
const CARD := Vector2(132, 260)
const CARD_GAP := 8.0
const CARD_Y := 150.0
## The part of each boss's art shown on its card, and the art pixel at its
## middle (the face).
const FACE := Vector2(124, 172)
const FACE_AT := {
	"lava_caves": Vector2(112, 190),
	"crystal_mines": Vector2(128, 168),
	"bog": Vector2(165, 178),
	"mushroom_forest": Vector2(84, 168),
	"space": Vector2(84, 150),
}
const INK := Color(0.96, 0.94, 0.9)
const GOLD := Color(1.0, 0.82, 0.35)
const TITLE_EDGE := Color(0.2, 0.1, 0.05)

var bosses := []  # [{world, name}] (Modes.bounce_bosses)
var choice: ChoiceWidget
var _tex := {}


func setup(save: Dictionary) -> void:
	bosses = Modes.bounce_bosses(save)


func _ready() -> void:
	add_child(MenuScene.new())
	for b in bosses:
		_tex[b["world"]] = load(WorldTheme.get_theme(b["world"])["boss_head"])
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for i in bosses.size():
		rects.append(card_rect(i))
	rects.append(BACK_RECT)
	choice.present(rects, 0)
	var i: int = await choice.picked
	if i < bosses.size():
		Beeper.good()
		picked.emit(String(bosses[i]["world"]))
	else:
		Beeper.tone(440.0, 0.08)
		back.emit()


func card_rect(i: int) -> Rect2:
	var n := bosses.size()
	var w := n * CARD.x + (n - 1) * CARD_GAP
	var x0 := roundf(480.0 - w / 2.0)
	return Rect2(x0 + i * (CARD.x + CARD_GAP), CARD_Y, CARD.x, CARD.y)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.06, 0.03, 0.05, 0.55))
	draw_string_outline(font, Vector2(120, 68), "Bounce", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, 12, TITLE_EDGE)
	draw_string(font, Vector2(120, 68), "Bounce", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color(1.0, 0.6, 0.25))
	RoundBox.fill(self, BACK_RECT, Color(0.42, 0.36, 0.33), 14.0)
	draw_string(font, BACK_RECT.position + Vector2(0, 47), "Back", HORIZONTAL_ALIGNMENT_CENTER, BACK_RECT.size.x, 30, INK)
	for i in bosses.size():
		_draw_card(font, i)


## A boss's card: its world's color, the face, the world's name under it.
func _draw_card(font: Font, i: int) -> void:
	var r := card_rect(i)
	var wid := String(bosses[i]["world"])
	RoundBox.fill(self, r, Color(0.16, 0.11, 0.1, 0.92), 14.0)
	RoundBox.frame(self, r, GOLD, 3.0, 14.0)
	var tex: Texture2D = _tex.get(wid)
	if tex != null:
		var at: Vector2 = FACE_AT.get(wid, Vector2(tex.get_width(), tex.get_height()) / 2.0)
		var src := Rect2((at - FACE / 2.0).round(), FACE)
		src.position.x = clampf(src.position.x, 0, tex.get_width() - FACE.x)
		src.position.y = clampf(src.position.y, 0, tex.get_height() - FACE.y)
		draw_texture_rect_region(tex, Rect2(r.position + Vector2(4, 6), FACE), src)
	var words := String(bosses[i]["name"]).split(" ")
	var y := r.position.y + FACE.y + 36
	for k in words.size():
		draw_string(font, Vector2(r.position.x, y + 24 * k), words[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, INK)
