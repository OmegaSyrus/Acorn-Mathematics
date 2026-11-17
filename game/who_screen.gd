## "Who is playing?" (parent app plan v2): one card per child on this
## tablet, with their picture and name, and a Guest card last. A Guest plays
## and saves here but never syncs. Shown at launch when two or more children
## share the tablet, and from the player button on the main menu (then with
## Back). Tapping a card picks that player.
extends Node2D

## The picked profile id, or GUEST for the Guest card.
signal picked(profile_id: String)
signal back

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Profiles := preload("res://logic/core/profiles.gd")

const GUEST := "guest"
const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const BACK_RECT := Rect2(120, 20, 140, 60)
const CARD := Vector2(160, 180)
const GAP := 16.0
const ROWS_Y := [120.0, 320.0]
const PER_ROW := 4
const ONE_ROW_Y := 200.0

var roster: Dictionary
var can_back := false
var cards: Array = []  # [{rect, id, nickname, picture, active}]
var choice: ChoiceWidget


func setup(r: Dictionary, with_back: bool) -> void:
	roster = r
	can_back = with_back


## The card rects for n cards: rows of four, centred in the 4:3 band.
static func card_rects(n: int) -> Array:
	var out := []
	for i in n:
		var row := i / PER_ROW
		var in_row := mini(PER_ROW, n - row * PER_ROW)
		var w := in_row * CARD.x + (in_row - 1) * GAP
		var x0 := 480.0 - w / 2.0
		var y: float = ROWS_Y[mini(row, 1)] if n > PER_ROW else ONE_ROW_Y
		out.append(Rect2(Vector2(roundf(x0 + (i % PER_ROW) * (CARD.x + GAP)), y), CARD))
	return out


func _ready() -> void:
	var active_id := str(roster.get("active", ""))
	var entries := []
	for p in Profiles.children(roster):
		entries.append({"id": p["id"], "nickname": p["nickname"], "picture": p["picture"], "active": p["id"] == active_id})
	var g := Profiles.guest_profile(roster)
	entries.append({"id": GUEST, "nickname": Profiles.GUEST_NAME, "picture": Profiles.GUEST_PICTURE,
			"active": not g.is_empty() and g["id"] == active_id, "guest": true})
	var rects := card_rects(entries.size())
	for e in entries:
		picture(str(e["picture"]))
	for i in entries.size():
		entries[i]["rect"] = rects[i]
		cards.append(entries[i])
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	var targets := []
	for c in cards:
		targets.append(c["rect"])
	if can_back:
		targets.append(BACK_RECT)
	choice.present(targets, 0)
	var k: int = await choice.picked
	if k >= cards.size():
		back.emit()
		return
	Beeper.good()
	picked.emit(str(cards[k]["id"]))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.12, 0.1))
	draw_string(font, Vector2(120, 84), "Who is playing?", HORIZONTAL_ALIGNMENT_CENTER, 720, 44, GOLD)
	if can_back:
		RoundBox.fill(self, BACK_RECT, Color(0.3, 0.27, 0.26), 14.0)
		draw_string(font, BACK_RECT.position + Vector2(0, 41), "Back", HORIZONTAL_ALIGNMENT_CENTER, BACK_RECT.size.x, 30, INK)
	for c in cards:
		var r: Rect2 = c["rect"]
		var col := Color(0.28, 0.24, 0.3) if c.get("guest", false) else Color(0.22, 0.36, 0.26)
		RoundBox.fill(self, r, col, 18.0)
		if c["active"]:
			RoundBox.frame(self, r, GOLD, 4.0, 18.0)
		var tex := picture(str(c["picture"]))
		if tex != null:
			# one art pixel = one unit, never scaled (game/ui/look.gd)
			var at := Vector2(r.get_center().x - tex.get_width() / 2.0, r.position.y + 128 - tex.get_height()).round()
			draw_texture(tex, at)
		draw_string(font, r.position + Vector2(0, 162), str(c["nickname"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, INK)


static var _pictures := {}


## A profile picture (art/heroes), loaded once. Screens call it from
## _ready, before drawing, so the texture is ready when _draw runs.
static func picture(id: String) -> Texture2D:
	if not _pictures.has(id):
		var p := "res://art/heroes/%s.png" % id
		_pictures[id] = load(p) if ResourceLoader.exists(p) else null
	return _pictures[id]
