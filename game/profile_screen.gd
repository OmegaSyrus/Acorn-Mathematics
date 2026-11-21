## The profile page (profile plan S3, 2026-11-21), from the main menu's
## player button. Left: the player's full picture at 1:1 on a card with
## their name. Right: four stat cards, Level, worlds done at that Level out
## of 5, stars, and gems with the other open currencies. Under them "Swap"
## (the switcher, S1), "Edit" with a lock (the PIN, then the edit screen,
## S4; not for Guest) and "Play" (the main action, to the world map).
## main.gd passes the numbers (ProfileStore.stats) and does every step.
extends Node2D

signal play
signal swap
signal edit
signal back

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const M3 := preload("res://game/ui/m3.gd")
const Marks := preload("res://game/ui/marks.gd")
const CurrencyIcon := preload("res://game/ui/currency_icon.gd")
const WhoScreen := preload("res://game/who_screen.gd")

const AVATAR_CARD := Rect2(128, 104, 240, 304)
const STATS_X := 384.0
const STAT := Vector2(216, 144)
const STAT_GAP := 16.0
const BUTTONS_Y := 432.0

## Which button each target index is, in targets() order.
enum Act { BACK, SWAP, EDIT, PLAY }

var profile: Dictionary = {}  # {id, nickname, picture, guest}
var stats: Dictionary = {}    # Profiles.stats()
var acts: Array = []          # [{act, rect}]
var choice: ChoiceWidget


func setup(p: Dictionary, s: Dictionary) -> void:
	profile = p
	stats = s
	acts = layout(bool(p.get("guest", false)))


## The tap targets: back arrow, Swap, Edit (not for Guest) and Play.
static func layout(guest: bool) -> Array:
	var out := [{"act": Act.BACK, "rect": M3.top_bar_back_rect()}]
	var x := AVATAR_CARD.position.x
	var sw := M3.button_rect(Vector2(x, BUTTONS_Y), "Swap", M3.Icon.SWAP)
	out.append({"act": Act.SWAP, "rect": sw})
	if not guest:
		out.append({"act": Act.EDIT, "rect": M3.button_rect(Vector2(sw.end.x + M3.GRID * 2, BUTTONS_Y), "Edit",
				M3.Icon.LOCK)})
	var pw := M3.button_width("Play")
	var right := STATS_X + STAT.x * 2 + STAT_GAP
	out.append({"act": Act.PLAY, "rect": Rect2(Vector2(right - pw, BUTTONS_Y), Vector2(pw, M3.BUTTON_H))})
	return out


static func stat_rect(i: int) -> Rect2:
	return Rect2(Vector2(STATS_X + (i % 2) * (STAT.x + STAT_GAP), AVATAR_CARD.position.y + (i / 2) * (STAT.y + STAT_GAP)),
			STAT)


func targets() -> Array:
	var out := []
	for a in acts:
		out.append(a["rect"])
	return out


func _ready() -> void:
	WhoScreen.picture(str(profile.get("picture", "")))  # loaded before _draw
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	choice.present(targets(), acts.size() - 1)
	var k: int = await choice.picked
	match int(acts[k]["act"]):
		Act.PLAY:
			_beep()
			play.emit()
		Act.SWAP:
			swap.emit()
		Act.EDIT:
			edit.emit()
		_:
			back.emit()


func _draw() -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), M3.SURFACE)
	M3.top_bar(self, str(profile.get("nickname", "")), true)
	# the player, full size at 1:1
	M3.card(self, AVATAR_CARD)
	var tex := WhoScreen.picture(str(profile.get("picture", "")))
	if tex != null:
		var at := Vector2(AVATAR_CARD.get_center().x - tex.get_width() / 2.0,
				AVATAR_CARD.position.y + 200 - tex.get_height()).round()
		draw_texture(tex, at)
	M3.text_center(self, Rect2(AVATAR_CARD.position + Vector2(8, 216), Vector2(AVATAR_CARD.size.x - 16, 48)),
			str(profile.get("nickname", "")), M3.HEADLINE - 8, M3.ON_SURFACE)
	# the four numbers
	_stat(0, "Level", str(int(stats.get("level", 1))))
	_stat(1, "Worlds", "%d/%d" % [int(stats.get("worlds_done", 0)), int(stats.get("worlds", 5))])
	_stat(2, "Stars", str(int(stats.get("stars", 0))))
	_money(3)
	for a in acts:
		var r: Rect2 = a["rect"]
		match int(a["act"]):
			Act.SWAP:
				M3.button(self, r, "Swap", M3.Style.TONAL, M3.Icon.SWAP)
			Act.EDIT:
				M3.button(self, r, "Edit", M3.Style.TONAL, M3.Icon.LOCK)
			Act.PLAY:
				M3.button(self, r, "Play", M3.Style.FILLED)


func _stat(i: int, label: String, value: String) -> void:
	var r := stat_rect(i)
	M3.card(self, r)
	M3.text_left(self, Rect2(r.position + Vector2(20, 12), Vector2(r.size.x - 40, 28)), label, M3.BODY,
			M3.ON_SURFACE_VARIANT)
	if i == 2:
		Marks.draw_star(self, r.position + Vector2(r.size.x - 36, 20))
	M3.text_left(self, Rect2(r.position + Vector2(20, 52), Vector2(r.size.x - 40, 76)), value, M3.DISPLAY,
			M3.PRIMARY)


## Gems and the other open currencies: one icon and amount per line, gems
## first and biggest.
func _money(i: int) -> void:
	var r := stat_rect(i)
	M3.card(self, r)
	var list: Array = stats.get("currencies", [])
	if list.is_empty():
		return
	var first: Dictionary = list[0]
	CurrencyIcon.draw(self, str(first["id"]), r.position + Vector2(40, 40), 40)
	M3.text_left(self, Rect2(r.position + Vector2(72, 16), Vector2(r.size.x - 88, 48)), str(int(first["amount"])),
			M3.HEADLINE, M3.PRIMARY)
	# the rest, two per line under the gems
	for j in range(1, list.size()):
		var c: Dictionary = list[j]
		var col := (j - 1) % 2
		var row := (j - 1) / 2
		var at := r.position + Vector2(20 + col * 100, 76 + row * 32)
		CurrencyIcon.draw(self, str(c["id"]), at + Vector2(12, 12), 24)
		M3.text_left(self, Rect2(at + Vector2(30, 0), Vector2(64, 24)), str(int(c["amount"])), M3.BODY,
				M3.ON_SURFACE)


## The pick beep. Through the tree, not the Beeper name, so the headless
## tests can load this script without the autoloads.
func _beep() -> void:
	var b := get_node_or_null("/root/Beeper")
	if b != null:
		b.call("good")
