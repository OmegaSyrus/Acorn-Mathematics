## The store (2026-11-05, Terrence): spend gems on heroes and dice skins.
## Two tabs (heroes, dice) of big cards, six by two, all inside what a 4:3
## tablet shows (x 120..840). Each card: the picture, the price with its
## currency's icon, and what a tap does:
##   a green "Buy" (enough gems): the first tap picks it and a big Buy
##     button pops up, the second tap buys (with a chime) and puts it on;
##   a grey "Buy" (not enough yet): the card shakes;
##   a lock (a currency the game can't give yet): the card shakes;
##   a blue "Use" (owned): puts it on; a check mark: in use.
## All rules live in logic/core/store.gd; the catalog is content/store.json.
extends Node2D

signal back

const Store := preload("res://logic/core/store.gd")
const SaveStore := preload("res://game/save_store.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const DiceSkins := preload("res://game/ui/dice_skins.gd")
const Look := preload("res://game/ui/look.gd")
const GEM_TEX := preload("res://art/lava/gem.png")

const BACK_RECT := Rect2(136, 10, 150, 80)
const TAB_RECTS := {"hero": Rect2(302, 10, 150, 80), "dice": Rect2(462, 10, 150, 80)}
const GEMS_BOX := Rect2(628, 14, 196, 72)
const COLS := 6
const CARD := Vector2(108, 205)
const GAP := 8.0
const GRID_X := 136.0
const GRID_YS := [104.0, 320.0]
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const BG := Color(0.13, 0.09, 0.08)
const CARD_COL := {
	Store.EQUIPPED: Color(0.27, 0.42, 0.28),
	Store.OWNED: Color(0.42, 0.36, 0.33),
	Store.BUY: Color(0.46, 0.28, 0.6),
	Store.SHORT: Color(0.3, 0.26, 0.26),
	Store.LOCKED: Color(0.19, 0.17, 0.2),
}
const BUY_GREEN := Color(0.2, 0.62, 0.3)
const USE_BLUE := Color(0.22, 0.45, 0.78)
const GOLD := Color(1.0, 0.82, 0.35)
const SHAKE_S := 0.45

var save: Dictionary
var persist := true       # false: stills and tests leave the profile file alone
var cat: Dictionary
var tab := "hero"
var selected := ""        # a Buy card tapped once: its big Buy button shows
var targets: Array = []   # [{rect, what: back|tab|card|buy, id}]
var choice: ChoiceWidget
var shown_gems := 0.0
var _shake := {}          # item id -> seconds of shake left
var _pop := {}            # item id -> seconds of pop left (bought / put on)
var _sparks: Array = []   # [{pos, vel, life, col}]
var _t := 0.0


func setup(profile: Dictionary) -> void:
	save = profile


func _ready() -> void:
	cat = Store.catalog()
	shown_gems = Store.balance(save, "gems")
	choice = ChoiceWidget.new()
	add_child(choice)
	# the highlight (keyboard and pad) starts on the hero in use
	_present({"what": "card", "id": Store.equipped(cat, save, tab)})
	_loop()


func _loop() -> void:
	while true:
		var i: int = await choice.picked
		var t: Dictionary = targets[i]
		match t["what"]:
			"back":
				Beeper.tone(440.0, 0.08)
				back.emit()
				return
			"tab":
				if t["id"] != tab:
					tab = t["id"]
					selected = ""
					Beeper.tone(523.0, 0.07)
			"buy":
				_buy(t["id"])
			"card":
				_tap_card(t["id"])
		_present(t)


func _tap_card(id: String) -> void:
	match Store.state(cat, save, id):
		Store.BUY:
			if selected == id:
				_buy(id)
			else:
				selected = id
				Beeper.tone(523.0, 0.07)
				get_tree().create_timer(0.08).timeout.connect(Beeper.tone.bind(784.0, 0.09))
		Store.OWNED:
			selected = ""
			Store.equip(cat, save, id)
			_saved()
			_pop[id] = 0.5
			Beeper.good()
		Store.EQUIPPED:
			selected = ""
			_pop[id] = 0.35
			Beeper.tone(660.0, 0.08)
		_:
			# not yet: too dear, or a currency the game can't give yet
			selected = ""
			_shake[id] = SHAKE_S
			Beeper.tone(196.0, 0.16, -10.0)
			get_tree().create_timer(0.15).timeout.connect(Beeper.tone.bind(165.0, 0.2, -10.0))


## Buys and puts it on straight away (a child who buys the slime wants to
## play the slime), with a chime, sparkles and the gem count running down.
func _buy(id: String) -> void:
	selected = ""
	if not Store.buy(cat, save, id):
		_shake[id] = SHAKE_S
		return
	Store.equip(cat, save, id)
	_saved()
	_pop[id] = 0.6
	Beeper.good()
	Beeper.gems(5)
	var c := _card_rect(_tab_items().find(Store.item(cat, id))).get_center()
	for k in 26:
		var a := TAU * k / 26.0 + randf() * 0.2
		_sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * randf_range(140.0, 320.0), "life": randf_range(0.6, 1.0),
				"col": [GOLD, Color(1, 1, 1), Color(0.6, 0.9, 1.0), Color(1.0, 0.6, 0.85)][k % 4]})
	create_tween().tween_property(self, "shown_gems", float(Store.balance(save, "gems")), 0.7)


func _saved() -> void:
	if persist:
		SaveStore.write(save)
	Look.apply(save)


func _tab_items() -> Array:
	return Store.items(cat, tab)


func _card_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(GRID_X + col * (CARD.x + GAP), GRID_YS[mini(row, 1)], CARD.x, CARD.y)


## The big Buy button over a picked card's lower half.
func _buy_rect(i: int) -> Rect2:
	var r := _card_rect(i)
	return Rect2(r.position.x - 6, r.position.y + 156, r.size.x + 12, 52)


## Rebuilds the targets (the Buy button first, so it wins where it overlaps
## its card) and hands them to the choice widget, the highlight on the
## target picked last (`last`, a target dictionary).
func _present(last: Dictionary) -> void:
	targets = []
	var items := _tab_items()
	if selected != "":
		var si := items.find(Store.item(cat, selected))
		if si >= 0:
			targets.append({"rect": _buy_rect(si), "what": "buy", "id": selected})
	targets.append({"rect": BACK_RECT, "what": "back", "id": ""})
	for k in TAB_RECTS:
		targets.append({"rect": TAB_RECTS[k], "what": "tab", "id": k})
	for i in mini(items.size(), COLS * 2):
		targets.append({"rect": _card_rect(i), "what": "card", "id": items[i]["id"]})
	var rects := []
	for t in targets:
		rects.append(t["rect"])
	choice.present(rects, _index_of(last))


## Where the target picked last sits in the new list: a card just picked
## for buying hands it to its Buy button, a Buy button once used to its card.
func _index_of(t: Dictionary) -> int:
	var what: String = "card" if t["what"] == "buy" else t["what"]
	if selected != "" and what == "card" and t["id"] == selected:
		return 0
	for i in targets.size():
		if targets[i]["what"] == what and targets[i]["id"] == t["id"]:
			return i
	return 0


func _process(delta: float) -> void:
	_t += delta
	for d in [_shake, _pop]:
		for k in d.keys():
			d[k] -= delta
			if d[k] <= 0.0:
				d.erase(k)
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] = s["vel"] * 0.93 + Vector2(0, 420.0 * delta)
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), BG)
	_draw_back(font)
	_draw_tabs()
	_draw_gems(font)
	var items := _tab_items()
	for i in mini(items.size(), COLS * 2):
		_draw_card(font, items[i], _card_rect(i), i)
	for s in _sparks:
		var a: float = clampf(s["life"] * 2.0, 0.0, 1.0)
		_star(s["pos"], 7.0, Color(s["col"], a), Color(DARK, a * 0.6))


func _draw_back(font: Font) -> void:
	var r := BACK_RECT
	RoundBox.fill(self, r, Color(0.42, 0.36, 0.33), 18.0)
	var c := r.position + Vector2(34, r.size.y / 2.0)
	var arrow := PackedVector2Array([c + Vector2(-18, 0), c + Vector2(4, -20), c + Vector2(4, -9), c + Vector2(20, -9),
			c + Vector2(20, 9), c + Vector2(4, 9), c + Vector2(4, 20)])
	draw_colored_polygon(arrow, GOLD)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), DARK, 2.0)
	draw_string(font, r.position + Vector2(58, r.size.y / 2.0 + 11), "Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)


## The tabs are pictures: the hero in use, and a pair of dice in the skin in
## use (one red, the take-away die).
func _draw_tabs() -> void:
	for k in TAB_RECTS:
		var r: Rect2 = TAB_RECTS[k]
		var on: bool = k == tab
		RoundBox.fill(self, r, Color(0.5, 0.4, 0.34) if on else Color(0.24, 0.19, 0.18), 18.0)
		if on:
			RoundBox.frame(self, r, GOLD, 4.0, 18.0)
		if k == "hero":
			var tex := Look.hero_texture()
			var s := 66.0 / tex.get_height()
			var size := tex.get_size() * s
			draw_texture_rect(tex, Rect2(r.get_center() - size / 2.0 + Vector2(0, 2), size), false,
					Color.WHITE if on else Color(0.7, 0.7, 0.7))
		else:
			var m := Color.WHITE if on else Color(0.7, 0.7, 0.7)
			draw_texture_rect(DiceSkins.face(Look.dice_id, 5), Rect2(r.get_center() + Vector2(-50, -26), Vector2(52, 52)), false, m)
			draw_texture_rect(DiceSkins.face(Look.dice_id, 2, true), Rect2(r.get_center() + Vector2(2, -20), Vector2(46, 46)), false, m)


func _draw_gems(font: Font) -> void:
	var r := GEMS_BOX
	RoundBox.fill(self, r, Color(0.1, 0.06, 0.1, 0.9), 16.0)
	RoundBox.frame(self, r, Color(1.0, 0.6, 0.25), 3.0, 16.0)
	draw_texture_rect(GEM_TEX, Rect2(r.position + Vector2(14, 8), Vector2(56, 56)), false)
	var at := r.position + Vector2(78, 50)
	var n := str(roundi(shown_gems))
	draw_string_outline(font, at, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, 6, DARK)
	draw_string(font, at, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(1.0, 0.86, 0.5))


func _draw_card(font: Font, it: Dictionary, r: Rect2, i: int) -> void:
	var id: String = it["id"]
	var st := Store.state(cat, save, id)
	if _shake.has(id):
		var k: float = _shake[id] / SHAKE_S
		r.position.x += sin(_shake[id] * 60.0) * 9.0 * k
	var pop := 0.0
	if _pop.has(id):
		pop = sin(clampf(1.0 - _pop[id] / 0.6, 0.0, 1.0) * PI) * 0.12
	var bg: Color = CARD_COL[st]
	RoundBox.fill(self, r, bg, 16.0)
	if st == Store.EQUIPPED:
		RoundBox.frame(self, r, Color(0.55, 0.95, 0.5), 3.0, 16.0)
	elif selected == id:
		RoundBox.frame(self, r, GOLD, 4.0, 16.0)
	# the picture, standing on the card's middle line
	var pic := Rect2(r.position + Vector2(4, 6), Vector2(r.size.x - 8, 126))
	var tint := Color.WHITE
	if st == Store.LOCKED:
		# dim, but still easy to make out: something to look forward to
		tint = Color(0.55, 0.53, 0.62) if it["kind"] == "hero" else Color(0.78, 0.76, 0.84)
	elif st == Store.SHORT:
		tint = Color(0.85, 0.85, 0.85)
	if it["kind"] == "hero":
		var tex := Look.hero_texture(id)
		var s := minf(1.0, minf(pic.size.x / tex.get_width(), pic.size.y / tex.get_height())) * (1.0 + pop)
		var bob := 0.0
		if st == Store.EQUIPPED:
			bob = absf(sin(_t * 2.4)) * 3.0
		var size := tex.get_size() * s
		var feet := Vector2(pic.get_center().x, pic.end.y - bob)
		draw_set_transform(Vector2(feet.x, pic.end.y - 3), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(tex, Rect2(feet - Vector2(size.x / 2.0, size.y), size), false, tint)
	else:
		var big := 74.0 * (1.0 + pop)
		var c := pic.get_center() + Vector2(-8, -6)
		draw_texture_rect(DiceSkins.face(id, 5), Rect2(c - Vector2(big, big) / 2.0, Vector2(big, big)), false, tint)
		var small := 44.0 * (1.0 + pop)
		var c2 := c + Vector2(34, 40)
		draw_texture_rect(DiceSkins.face(id, 2, true), Rect2(c2 - Vector2(small, small) / 2.0, Vector2(small, small)), false, tint)
	# what a tap does
	var mid := r.position.x + r.size.x / 2.0
	match st:
		Store.EQUIPPED:
			_check(Vector2(mid, r.position.y + 168), 24.0)
		Store.OWNED:
			_pill(font, Rect2(r.position + Vector2(8, 148), Vector2(r.size.x - 16, 46)), USE_BLUE, "Use", INK)
		_:
			_draw_price(font, it["price"], Vector2(mid, r.position.y + 148), st == Store.LOCKED)
			var pr := Rect2(r.position + Vector2(10, 164), Vector2(r.size.x - 20, 34))
			if st == Store.LOCKED:
				_lock(Vector2(mid, pr.get_center().y + 2), 30.0)
			elif st == Store.SHORT:
				_pill(font, pr, Color(0.4, 0.38, 0.38), "Buy", Color(0.62, 0.6, 0.6))
			elif selected == id:
				_draw_buy_button(font, _buy_rect(i))
			else:
				_pill(font, pr, BUY_GREEN, "Buy", INK)


## The price: the currency's icon and the amount.
func _draw_price(font: Font, price: Dictionary, c: Vector2, dim: bool) -> void:
	var n := str(price["amount"])
	var w := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var left := c.x - (26.0 + 4.0 + w) / 2.0
	_currency_icon(price["currency"], Vector2(left + 13, c.y - 9), 26.0)
	draw_string(font, Vector2(left + 30, c.y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(0.75, 0.72, 0.72) if dim else INK)


func _pill(font: Font, r: Rect2, col: Color, text: String, ink: Color) -> void:
	RoundBox.fill(self, r, col, r.size.y / 2.0)
	draw_string(font, Vector2(r.position.x, r.get_center().y + 10), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, ink)


## The Buy button a first tap brings up: big, green, breathing, like Go.
func _draw_buy_button(font: Font, r: Rect2) -> void:
	var s := 1.0 + 0.05 * sin(_t * 5.0)
	r = Rect2(r.get_center() - r.size * s / 2.0, r.size * s)
	RoundBox.fill(self, r.grow(5), GOLD, 22.0)
	RoundBox.fill(self, r, BUY_GREEN, 18.0)
	var at := Vector2(r.position.x, r.get_center().y + 13)
	draw_string_outline(font, at, "Buy", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, 7, DARK)
	draw_string(font, at, "Buy", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, INK)


func _check(c: Vector2, rad: float) -> void:
	draw_circle(c, rad + 3.0, DARK)
	draw_circle(c, rad, Color(0.3, 0.75, 0.32))
	var pts := PackedVector2Array([c + Vector2(-11, 1), c + Vector2(-3, 9), c + Vector2(12, -8)])
	draw_polyline(pts, INK, 6.0, true)


## A padlock: a gold body with a keyhole under a grey shackle.
func _lock(c: Vector2, size: float) -> void:
	var w := size
	var h := size * 0.75
	var body := Rect2(c.x - w / 2.0, c.y - h / 2.0 + size * 0.12, w, h)
	draw_arc(Vector2(c.x, body.position.y), w * 0.3, PI, TAU, 16, DARK, size * 0.26)
	draw_arc(Vector2(c.x, body.position.y), w * 0.3, PI, TAU, 16, Color(0.75, 0.75, 0.8), size * 0.14)
	RoundBox.fill(self, body.grow(2), DARK, 6.0)
	RoundBox.fill(self, body, GOLD, 5.0)
	draw_circle(body.get_center() + Vector2(0, -3), size * 0.1, DARK)
	draw_rect(Rect2(body.get_center() + Vector2(-size * 0.04, -3), Vector2(size * 0.08, size * 0.22)), DARK)


## Currency icons, drawn from the catalog's icon spec (shape and colours),
## so a new currency needs only data. Gems use the gem art.
func _currency_icon(cid: String, c: Vector2, size: float) -> void:
	var icon: Dictionary = cat["currencies"].get(cid, {}).get("icon", {})
	var col := Color(icon.get("color", "#cccccc"))
	var light := Color(icon.get("light", "#ffffff"))
	var h := size / 2.0
	match str(icon.get("shape", "")):
		"gem":
			draw_texture_rect(GEM_TEX, Rect2(c - Vector2(h, h) * 1.15, Vector2(size, size) * 1.15), false)
		"crystal":
			var p := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.55, -h * 0.45), c + Vector2(h * 0.55, h * 0.55),
					c + Vector2(0, h), c + Vector2(-h * 0.55, h * 0.55), c + Vector2(-h * 0.55, -h * 0.45)])
			_shape(p, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(-h * 0.55, -h * 0.45), c + Vector2(-h * 0.55, h * 0.55),
					c + Vector2(0, h)]), light)
		"leaf":
			var p := PackedVector2Array()
			for k in 16:
				var t := TAU * k / 16.0
				p.append(c + Vector2(sin(t) * h * 0.55 * (1.0 - 0.3 * cos(t)), -cos(t) * h).rotated(0.5))
			_shape(p, col)
			draw_line(c + Vector2(0, h).rotated(0.5), c + Vector2(0, -h * 0.7).rotated(0.5), light, 2.0)
		"feather":
			var p := PackedVector2Array()
			for k in 16:
				var t := TAU * k / 16.0
				p.append(c + Vector2(sin(t) * h * 0.4, -cos(t) * h).rotated(-0.6))
			_shape(p, light)
			draw_line(c + Vector2(0, h * 1.1).rotated(-0.6), c + Vector2(0, -h * 0.8).rotated(-0.6), col, 2.5)
		"star":
			_star(c, h, col, DARK)
			draw_circle(c + Vector2(-h * 0.2, -h * 0.2), h * 0.18, light)
		_:
			draw_circle(c, h, col)


func _shape(p: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(p, col)
	var ring := p.duplicate()
	ring.append(p[0])
	draw_polyline(ring, DARK, 2.0, true)


func _star(c: Vector2, r: float, col: Color, rim: Color) -> void:
	var p := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + PI * k / 5.0
		p.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(p, col)
	var ring := p.duplicate()
	ring.append(p[0])
	draw_polyline(ring, rim, 1.5, true)
