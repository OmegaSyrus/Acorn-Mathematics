## The monster book (Phase 6, 2026-11-28), from the main menu's Book button.
## A page per world (the tabs along the top, in map order): a card for each
## of its monsters and its miniboss, in Monsters.ROSTER order. A card shows
## the fighter and its name once it has been beaten (Book.record), and a dark
## shape with a "?" before. Under the cards, the world's boss and a row of
## six trophies, one per Level, gold once the boss is beaten at that Level
## (Book.trophy_at). Characters are never scaled (Look.CHAR_PX): a fighter
## bigger than its card shows its top part (the head), cut to the card.
## Back returns to the main menu.
extends Node2D

signal back

const Book := preload("res://logic/core/book.gd")
const Monsters := preload("res://logic/fight/monsters.gd")
const Content := preload("res://logic/core/content.gd")
const WorldTheme := preload("res://game/ui/world_theme.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Trophy := preload("res://game/ui/trophy.gd")

## The top bar, like the store's: Back, then a tab per world.
const BACK_RECT := Rect2(128, 10, 124, 80)
const TAB_X := 266.0
const TAB_STEP := 116.0
const TAB_SIZE := Vector2(108, 80)
## The cards: up to five in a row, inside the 4:3 band (x 124..836).
const CARD := Vector2(136, 226)
const CARD_Y := 104.0
const CARD_STEP := 144.0
const PIC := Vector2(128, 178)  # the window a fighter shows in
## The boss strip: the boss's face, then its six trophies.
const STRIP := Rect2(124, 342, 712, 186)
const FACE_WIN := Vector2(200, 166)
const LEVELS := 6
## Where each boss's face sits in its art (art pixels), for its window.
const FACE_AT := {
	"lava_caves": Vector2(120, 200),
	"crystal_mines": Vector2(160, 150),
	"bog": Vector2(190, 165),
	"mushroom_forest": Vector2(135, 165),
	"space": Vector2(115, 150),
}
const INK := Color(0.96, 0.94, 0.9)
const DIM_INK := Color(0.62, 0.6, 0.62)
const DARK := Color(0.07, 0.04, 0.08)
const BG := Color(0.12, 0.09, 0.1)
const GOLD := Color(1.0, 0.82, 0.35)
const SHADOW := Color(0.0, 0.0, 0.0, 1.0)

var save: Dictionary
var worlds: Array = []   # the worlds with a page, in map order
var pages := {}          # world id -> its fighter ids in roster order
var page := 0            # the world shown
var choice: ChoiceWidget
var _tops := {}          # texture -> the top row of its art (first row with a pixel)
var _tex := {}           # monster id or world id (its boss) -> texture, loaded before the first draw


func setup(profile: Dictionary) -> void:
	save = profile
	for w in Content.worlds():
		var wid := String(w["id"])
		var ids := []
		for id in Monsters.ROSTER:
			if WorldTheme.world_of_monster(id) == wid and WorldTheme.MONSTER_ART.has(id):
				ids.append(id)
		if not ids.is_empty():
			worlds.append(w)
			pages[wid] = ids
			for id in ids:
				_tex[id] = WorldTheme.monster_texture(id)
			# a texture first loaded inside _draw can come out white
			var head: String = WorldTheme.get_theme(wid).get("boss_head", "")
			if head != "" and ResourceLoader.exists(head):
				_tex[wid] = load(head)
	# open on the newest page with a card on it
	for i in worlds.size():
		for id in pages[String(worlds[i]["id"])]:
			if Book.has_card(save, id):
				page = i


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := [BACK_RECT]
	for i in worlds.size():
		rects.append(tab_rect(i))
	var at := page + 1
	while true:
		choice.present(rects, at)
		var i: int = await choice.picked
		if i == 0:
			Beeper.tone(440.0, 0.08)
			back.emit()
			return
		at = i
		if i - 1 != page:
			page = i - 1
			Beeper.tone(523.0, 0.07)
		queue_redraw()


func tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(TAB_X + i * TAB_STEP, 10), TAB_SIZE)


func card_rect(k: int, n: int) -> Rect2:
	var x0 := 124.0 + (5 - n) * CARD_STEP / 2.0
	return Rect2(Vector2(roundf(x0 + k * CARD_STEP), CARD_Y), CARD)


func _world_color(w: Dictionary) -> Color:
	var rgb: Array = w.get("color", [0.8, 0.6, 0.4])
	return Color(rgb[0], rgb[1], rgb[2])


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), BG)
	_draw_back(font)
	for i in worlds.size():
		_draw_tab(i)
	if worlds.is_empty():
		return
	var w: Dictionary = worlds[page]
	var ids: Array = pages[String(w["id"])]
	for k in ids.size():
		_draw_card(font, ids[k], card_rect(k, ids.size()))
	_draw_boss_strip(font, w)


func _draw_back(font: Font) -> void:
	var r := BACK_RECT
	RoundBox.fill(self, r, Color(0.42, 0.36, 0.33), 18.0)
	var c := r.position + Vector2(34, r.size.y / 2.0)
	var arrow := PackedVector2Array([c + Vector2(-18, 0), c + Vector2(4, -20), c + Vector2(4, -9), c + Vector2(20, -9),
			c + Vector2(20, 9), c + Vector2(4, 9), c + Vector2(4, 20)])
	draw_colored_polygon(arrow, GOLD)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), DARK, 2.0)
	draw_string(font, r.position + Vector2(56, r.size.y / 2.0 + 10), "Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, INK)


## A world's tab: its color, a dot per fighter (gold once beaten) and a
## little trophy once its boss is beaten at any Level.
func _draw_tab(i: int) -> void:
	var r := tab_rect(i)
	var w: Dictionary = worlds[i]
	var on := i == page
	var col := _world_color(w)
	RoundBox.fill(self, r, col.darkened(0.15) if on else col.darkened(0.6), 16.0)
	if on:
		RoundBox.frame(self, r, GOLD, 4.0, 16.0)
	var ids: Array = pages[String(w["id"])]
	var dot := 12.0
	var gap := 6.0
	var x0 := r.get_center().x - (ids.size() * dot + (ids.size() - 1) * gap) / 2.0
	for k in ids.size():
		var p := Vector2(roundf(x0 + k * (dot + gap)), r.end.y - 24)
		draw_rect(Rect2(p, Vector2(dot, dot)), DARK)
		if Book.has_card(save, ids[k]):
			draw_rect(Rect2(p + Vector2(2, 2), Vector2(dot - 4, dot - 4)), Trophy.GOLD)
	var won := Book.bosses_beaten(save).has(String(w["id"]))
	Trophy.draw(self, Vector2(r.get_center().x - Trophy.size(2).x / 2.0, r.position.y + 10), won, 2, 1.0 if on else 0.8)


## One fighter's card: the art in its window, cut to it (never scaled), and
## its name; before it is beaten a black shape and a "?". Minibosses get a
## gold frame.
func _draw_card(font: Font, id: String, r: Rect2) -> void:
	var seen := Book.has_card(save, id)
	var boss := str(Monsters.ROSTER[id]["role"]) == "miniboss"
	RoundBox.fill(self, r, Color(0.3, 0.24, 0.24) if seen else Color(0.18, 0.15, 0.17), 14.0)
	if boss:
		RoundBox.frame(self, r, GOLD if seen else Color(0.45, 0.4, 0.3), 3.0, 14.0)
	var win := Rect2(r.position + Vector2((r.size.x - PIC.x) / 2.0, 4), PIC)
	draw_rect(win, Color(0.1, 0.08, 0.1) if seen else Color(0.13, 0.11, 0.13))
	var tex: Texture2D = _tex[id]
	_draw_fit(tex, win, Color.WHITE if seen else SHADOW)
	if seen:
		_draw_name(font, Monsters.name_of(id), Rect2(r.position.x + 2, win.end.y + 2, r.size.x - 4, r.end.y - win.end.y - 4))
	else:
		var at := Vector2(r.position.x, win.get_center().y + 22)
		draw_string_outline(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, 10, DARK)
		draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, Color(0.75, 0.72, 0.78))


## Draws a character at 1:1 inside a window: one that fits stands on the
## window's floor, one too big shows its middle across and its top down.
func _draw_fit(tex: Texture2D, win: Rect2, tint: Color) -> void:
	var size := tex.get_size()
	var top := _top_row(tex)
	var src := Rect2(Vector2.ZERO, size)
	var dst := Rect2()
	if size.x > win.size.x:
		src.position.x = roundf((size.x - win.size.x) / 2.0)
		src.size.x = win.size.x
	var art_h := size.y - top
	if art_h > win.size.y:
		src.position.y = top
		src.size.y = win.size.y
		dst.position.y = win.position.y
	else:
		src.position.y = top
		src.size.y = art_h
		dst.position.y = win.end.y - art_h - 4
	dst.size = src.size
	dst.position.x = roundf(win.get_center().x - src.size.x / 2.0)
	dst.position = dst.position.round()
	draw_texture_rect_region(tex, dst, src, tint)


## The first row of the art with a pixel in it, so a cut shows the head
## rather than empty space above it.
func _top_row(tex: Texture2D) -> int:
	if _tops.has(tex):
		return _tops[tex]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var top := int(img.get_used_rect().position.y)
	_tops[tex] = top
	return top


## A name in up to two lines (a word or two per line), small enough to fit.
func _draw_name(font: Font, text: String, r: Rect2) -> void:
	var size := 18
	var lines := [text]
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > r.size.x:
		var words := text.split(" ")
		var best := 1
		var best_w := 1e9
		for cut in range(1, words.size()):
			var a := " ".join(words.slice(0, cut))
			var b := " ".join(words.slice(cut))
			var wmax := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
					font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			if wmax < best_w:
				best_w = wmax
				best = cut
		lines = [" ".join(words.slice(0, best)), " ".join(words.slice(best))]
		while size > 13 and best_w > r.size.x:
			size -= 1
			best_w = maxf(font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
					font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var line_h := size + 3
	var y0 := r.get_center().y - line_h * lines.size() / 2.0 + size * 0.8
	for k in lines.size():
		draw_string(font, Vector2(r.position.x, y0 + k * line_h), lines[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, INK)


## The boss strip: the boss's face in a window (a dark shape until it is
## beaten at any Level), then a trophy per Level with its number under it.
func _draw_boss_strip(font: Font, w: Dictionary) -> void:
	var wid := String(w["id"])
	RoundBox.fill(self, STRIP, Color(0.2, 0.15, 0.16), 16.0)
	RoundBox.frame(self, STRIP, _world_color(w).darkened(0.3), 3.0, 16.0)
	var win := Rect2(STRIP.position + Vector2(10, (STRIP.size.y - FACE_WIN.y) / 2.0), FACE_WIN)
	draw_rect(win, Color(0.1, 0.08, 0.1))
	var beaten := Book.bosses_beaten(save).has(wid)
	if _tex.has(wid):
		var tex: Texture2D = _tex[wid]
		var at: Vector2 = FACE_AT.get(wid, tex.get_size() / 2.0)
		var src := Rect2((at - FACE_WIN / 2.0).round(), FACE_WIN)
		src.position = src.position.clamp(Vector2.ZERO, tex.get_size() - FACE_WIN)
		draw_texture_rect_region(tex, win, src, Color.WHITE if beaten else SHADOW)
	if not beaten:
		var q := Vector2(win.position.x, win.get_center().y + 22)
		draw_string_outline(font, q, "?", HORIZONTAL_ALIGNMENT_CENTER, win.size.x, 64, 10, DARK)
		draw_string(font, q, "?", HORIZONTAL_ALIGNMENT_CENTER, win.size.x, 64, Color(0.75, 0.72, 0.78))
	# a trophy per Level, four units to an art pixel so they read from afar
	var scale := 4
	var ts := Trophy.size(scale)
	var x0 := win.end.x + 18.0
	var step := (STRIP.end.x - 12.0 - x0 - ts.x) / (LEVELS - 1)
	for n in range(1, LEVELS + 1):
		var p := Vector2(roundf(x0 + (n - 1) * step), STRIP.position.y + 34)
		var won := Book.trophy_at(save, wid, n)
		Trophy.draw(self, p, won, scale)
		var at := Vector2(p.x - 10, p.y + ts.y + 40)
		draw_string_outline(font, at, str(n), HORIZONTAL_ALIGNMENT_CENTER, ts.x + 20, 34, 7, DARK)
		draw_string(font, at, str(n), HORIZONTAL_ALIGNMENT_CENTER, ts.x + 20, 34, INK if won else DIM_INK)
