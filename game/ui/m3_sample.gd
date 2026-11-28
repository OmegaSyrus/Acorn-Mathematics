## A sample screen for the Material kit (profile plan P1): every part of
## game/ui/m3.gd on one page, laid out like the profile screens will be (a
## top bar, one filled button, 7 avatar tiles of 96 across the safe band, a
## name field, a New card, the icons). `dialog_open` shows the Remove
## dialog over it. targets() lists every tap rect, for the touch test and
## for ChoiceWidget. Not used by the game itself.
extends Node2D

const M3 := preload("res://game/ui/m3.gd")

const BUTTONS := [
	["Play", M3.Style.FILLED, M3.Icon.CHECK],
	["Swap", M3.Style.TONAL, M3.Icon.SWAP],
	["Edit", M3.Style.OUTLINED, M3.Icon.PENCIL],
	["Back", M3.Style.TEXT, M3.Icon.NONE],
]
const BUTTON_Y := 104.0
const TILE := 96.0
const TILES := 7
const TILE_Y := 192.0
const FIELD := Rect2(128, 320, 400, 80)
const NEW_CARD := Rect2(560, 312, 272, 104)
const ICON_Y := 448.0
const ICONS := [M3.Icon.PLUS, M3.Icon.PENCIL, M3.Icon.CHECK, M3.Icon.BACK, M3.Icon.SWAP, M3.Icon.LOCK, M3.Icon.BIN]
const DIALOG_LABELS := ["Back", "Remove"]
const DIALOG_BODY := ["Hold Remove for 3 seconds.", "Wren's stars and gems go too."]

var dialog_open := false
var chosen_tile := 2
var name_text := "Wren"
var pressed := ""  # a target name drawn in its pressed state (stills)


static func button_rects() -> Array:
	var out := []
	var x := M3.SAFE.position.x + M3.GRID
	for b in BUTTONS:
		var r := M3.button_rect(Vector2(x, BUTTON_Y), b[0], b[2])
		out.append(r)
		x = r.end.x + M3.GRID * 2.0
	return out


static func tile_rect(i: int) -> Rect2:
	var gap := (M3.SAFE.size.x - TILES * TILE) / (TILES - 1)
	return Rect2(Vector2(M3.SAFE.position.x + i * (TILE + gap), TILE_Y), Vector2(TILE, TILE))


static func icon_rect(i: int) -> Rect2:
	var x := M3.SAFE.position.x + M3.GRID + i * (M3.ICON_BUTTON + M3.GRID * 2.0)
	return Rect2(Vector2(x, ICON_Y), Vector2(M3.ICON_BUTTON, M3.ICON_BUTTON))


## Every tap target now on screen: [{name, rect}]. With the dialog open,
## only its buttons can be tapped.
func targets() -> Array:
	var out := []
	if dialog_open:
		var rs := M3.dialog_button_rects(M3.dialog_rect(DIALOG_BODY.size()), DIALOG_LABELS)
		for i in rs.size():
			out.append({"name": "dialog_" + str(DIALOG_LABELS[i]).to_lower(), "rect": rs[i]})
		return out
	out.append({"name": "back", "rect": M3.top_bar_back_rect()})
	out.append({"name": "lock", "rect": M3.top_bar_action_rect(0)})
	out.append({"name": "pencil", "rect": M3.top_bar_action_rect(1)})
	var br := button_rects()
	for i in br.size():
		out.append({"name": str(BUTTONS[i][0]).to_lower(), "rect": br[i]})
	for i in TILES:
		out.append({"name": "tile_%d" % i, "rect": tile_rect(i)})
	out.append({"name": "field", "rect": FIELD})
	out.append({"name": "new", "rect": NEW_CARD})
	for i in ICONS.size():
		out.append({"name": "icon_%d" % i, "rect": icon_rect(i)})
	return out


func _state(name: String) -> M3.State:
	return M3.State.PRESSED if name == pressed else M3.State.NORMAL


func _draw() -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), M3.SURFACE)
	M3.top_bar(self, "Kit", true, _state("back"))
	M3.icon_button(self, M3.top_bar_action_rect(0), M3.Icon.LOCK, false, _state("lock"))
	M3.icon_button(self, M3.top_bar_action_rect(1), M3.Icon.PENCIL, false, _state("pencil"))
	var br := button_rects()
	for i in br.size():
		var b: Array = BUTTONS[i]
		M3.button(self, br[i], b[0], b[1], b[2], _state(str(b[0]).to_lower()))
	for i in TILES:
		var r := tile_rect(i)
		M3.card(self, r, i == chosen_tile, _state("tile_%d" % i))
		M3.text_center(self, r, str(i + 1), M3.HEADLINE, M3.ON_SURFACE_VARIANT)
	M3.text_field(self, FIELD, "Name", name_text, 12)
	M3.card(self, NEW_CARD, false, _state("new"))
	var plus := Rect2(NEW_CARD.position + Vector2(24, 28), Vector2(48, 48))
	draw_circle(plus.get_center(), 32.0, M3.PRIMARY_CONTAINER, true, -1.0, true)
	M3.draw_icon(self, M3.Icon.PLUS, plus, M3.ON_PRIMARY_CONTAINER)
	M3.text_left(self, Rect2(NEW_CARD.position + Vector2(104, 0), Vector2(160, NEW_CARD.size.y)), "New",
			M3.HEADLINE, M3.ON_SURFACE)
	for i in ICONS.size():
		M3.icon_button(self, icon_rect(i), ICONS[i], true, _state("icon_%d" % i))
	if dialog_open:
		M3.dialog(self, "Remove Wren?", DIALOG_BODY, DIALOG_LABELS, true, M3.Icon.BIN)
