## "Who is playing?", the switcher (profile plan S1, 2026-11-21): a grid of
## Material cards, four per row and two rows, one per child with their full
## picture at 1:1, their name and their star count. Then a Guest card and a
## "New" card with a plus. The current player has the gold ring and check.
## Six children plus Guest plus New fill the two rows exactly.
##
## Play mode (launch, or Swap on the profile page): a tap on a child or Guest
## picks them; "New" asks main.gd for the create flow (the PIN first when one
## is set, plan D2). Manage mode (Grown-ups, Children, after the PIN): Guest
## is left out, a tap on a child opens their edit screen (S4), and "New"
## makes a child. main.gd does every change; this screen only emits.
extends Node2D

## The picked profile id, or GUEST for the Guest card (play mode).
signal picked(profile_id: String)
## The "New" card.
signal add
## A child's card in manage mode.
signal edit(profile_id: String)
signal back

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const M3 := preload("res://game/ui/m3.gd")
const Marks := preload("res://game/ui/marks.gd")
const Look := preload("res://game/ui/look.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const ProfileStore := preload("res://game/profile_store.gd")

const GUEST := "guest"
const NEW := "new"
## A card: room for the tallest hero (124) at 1:1, the name and the stars.
const CARD := Vector2(160, 200)
const GAP := 24.0
const PER_ROW := 4
## The two rows under the top bar (80), and the one row when four or fewer.
const ROWS_Y := [96.0, 320.0]
const ONE_ROW_Y := 200.0
## Where the picture's feet stand inside a card, and the name and stars.
const FEET_Y := 132.0
const NAME_Y := 136.0
const STARS_Y := 170.0

var roster: Dictionary
var can_back := false
var manage := false
## Star counts by profile id. Filled from each save in _ready unless a
## caller (a test, the stills) set it first.
var stars: Dictionary = {}
var cards: Array = []  # [{rect, id, nickname, picture, active, guest, new}]
var choice: ChoiceWidget


## with_back adds the top bar's back arrow; manage_mode is the Grown-ups
## Children list (always with back).
func setup(r: Dictionary, with_back: bool, manage_mode := false) -> void:
	roster = r
	manage = manage_mode
	can_back = with_back or manage_mode


## The card rects for n cards: rows of four, centred in the safe band.
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


## The cards this roster shows, in order: the children, then Guest (play
## mode only), then New (while there is room for another child).
static func entries(r: Dictionary, manage_mode: bool) -> Array:
	var active_id := str(r.get("active", ""))
	var out := []
	for p in Profiles.children(r):
		out.append({"id": str(p["id"]), "nickname": str(p["nickname"]), "picture": str(p["picture"]),
				"active": str(p["id"]) == active_id, "guest": false, "new": false})
	if not manage_mode:
		var g := Profiles.guest_profile(r)
		out.append({"id": GUEST, "nickname": Profiles.GUEST_NAME, "picture": Profiles.GUEST_PICTURE,
				"active": not g.is_empty() and str(g["id"]) == active_id, "guest": true, "new": false})
	if Profiles.can_add(r):
		out.append({"id": NEW, "nickname": "New", "picture": "", "active": false, "guest": false, "new": true})
	return out


## Every rect a tap can land on: the cards, then the back arrow.
func targets() -> Array:
	var out := []
	for c in cards:
		out.append(c["rect"])
	if can_back:
		out.append(M3.top_bar_back_rect())
	return out


func _ready() -> void:
	var list := entries(roster, manage)
	var rects := card_rects(list.size())
	for i in list.size():
		list[i]["rect"] = rects[i]
		cards.append(list[i])
		if not list[i]["new"]:
			picture(str(list[i]["picture"]))  # loaded before _draw
		if not list[i]["new"] and not list[i]["guest"] and not stars.has(list[i]["id"]):
			stars[list[i]["id"]] = int(ProfileStore.stats(str(list[i]["id"])).get("stars", 0))
	var g := Profiles.guest_profile(roster)
	if not manage and not g.is_empty() and not stars.has(GUEST):
		stars[GUEST] = int(ProfileStore.stats(str(g["id"])).get("stars", 0))
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	choice.present(targets(), 0)
	var k: int = await choice.picked
	if k >= cards.size():
		back.emit()
		return
	var c: Dictionary = cards[k]
	_beep()
	if c["new"]:
		add.emit()
	elif manage:
		edit.emit(str(c["id"]))
	else:
		picked.emit(str(c["id"]))


func _draw() -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), M3.SURFACE)
	M3.top_bar(self, "Children" if manage else "Who is playing?", can_back)
	for c in cards:
		_draw_card(c)


func _draw_card(c: Dictionary) -> void:
	var r: Rect2 = c["rect"]
	M3.card(self, r, c["active"])
	if c["new"]:
		var disc := Rect2(r.get_center() - Vector2(40, 56), Vector2(80, 80))
		M3.icon_button(self, disc, M3.Icon.PLUS, true)
		M3.text_center(self, Rect2(r.position + Vector2(0, NAME_Y), Vector2(r.size.x, 32)), "New", M3.LABEL,
				M3.PRIMARY)
		return
	var tex := picture(str(c["picture"]))
	if tex != null:
		# one art pixel = one unit, never scaled (game/ui/look.gd)
		var at := Vector2(r.get_center().x - tex.get_width() / 2.0, r.position.y + FEET_Y - tex.get_height()).round()
		draw_texture(tex, at)
	M3.text_center(self, Rect2(r.position + Vector2(8, NAME_Y), Vector2(r.size.x - 16, 32)), str(c["nickname"]),
			M3.BODY, M3.ON_SURFACE)
	if manage:
		M3.draw_icon(self, M3.Icon.PENCIL, Rect2(r.position + Vector2(10, 10), Vector2(24, 24)),
				M3.ON_SURFACE_VARIANT)
	if stars.has(c["id"]):
		var label := str(int(stars[c["id"]]))
		var tw := M3.text_width(label, M3.SMALL)
		var x := roundf(r.get_center().x - (13 + 6 + tw) / 2.0)
		Marks.draw_star(self, Vector2(x, r.position.y + STARS_Y + 3))
		M3.text_left(self, Rect2(Vector2(x + 19, r.position.y + STARS_Y), Vector2(tw + 4, 20)), label, M3.SMALL,
				M3.ON_SURFACE_VARIANT)


## A profile picture (any of the 14 looks, Profiles.PICTURES), the way the
## shop draws it: Look.hero_texture paints the Bolt colours. Loaded once;
## screens call it from _ready so the texture is ready when _draw runs.
static func picture(id: String) -> Texture2D:
	if id == "":
		return null
	return Look.hero_texture(id)


## The pick beep. Through the tree, not the Beeper name, so the headless
## tests can load this script without the autoloads.
func _beep() -> void:
	var b := get_node_or_null("/root/Beeper")
	if b != null:
		b.call("good")
