## The main menu's living backdrop (Terrence 2026-11-12): a lush, serene oak
## on a hill, with birds flying over and animals wandering by now and then
## while the menu song loops. Ellwynn stands in front of the oak.
##
## Art (PixelLab, sum-dungeon/art-menu-oak/): the scene is 320x180 drawn at 3x
## like every background; the animals and birds are on the 1 unit grid like
## every character (never scaled). Leaves, far birds and butterflies are drawn
## here on the background's 3x grid.
##
## The map screen adds this as a child that draws behind it, so the buttons
## always sit on top and nothing here takes a tap.
extends Node2D

const BG := preload("res://art/menu/oak-hill.png")
const BG_SCALE := 3.0
const DESIGN := Vector2(960, 540)
## Outside the picture (very tall or very wide screens): its own sky and grass.
const SKY := Color(0.33, 0.6, 0.86)
const GRASS := Color(0.27, 0.42, 0.16)

## Walkers. Strips are frames side by side, feet on the bottom row, facing
## right (mirrored when walking left). `hop`: moves only on these frames.
const CRITTERS := {
	"fox": {"tex": preload("res://art/menu/fox.png"), "w": 63, "fps": 10.0, "speed": 46.0, "lane": "hill"},
	"deer": {"tex": preload("res://art/menu/deer.png"), "w": 56, "fps": 8.0, "speed": 32.0, "lane": "hill"},
	"rabbit": {"tex": preload("res://art/menu/rabbit.png"), "w": 28, "fps": 10.0, "speed": 70.0, "lane": "front",
			"hop": [3, 4, 5, 6]},
	"hedgehog": {"tex": preload("res://art/menu/hedgehog.png"), "w": 27, "fps": 8.0, "speed": 18.0, "lane": "front"},
}
const BIRD := preload("res://art/menu/bird.png")
const BIRD_W := 32
const BIRD_FPS := 12.0

## The hill lane: along the grass on top of the oak's hill (behind Ellwynn),
## down its right side and across the meadow (behind Play and Shop), in design
## units, measured on the picture.
const HILL_PATH := [
	Vector2(-90, 411), Vector2(0, 411), Vector2(150, 396), Vector2(300, 402), Vector2(345, 412),
	Vector2(375, 435), Vector2(405, 456), Vector2(440, 468), Vector2(1060, 470),
]
## The front lane: along the bottom edge, in the flowers under the buttons.
const FRONT_Y := 539.0
## Where a walker may stop for a moment, where it can be seen.
const PAUSE_SPOTS := {"hill": [[24, 100], [300, 360], [840, 912]], "front": [[40, 110], [310, 380], [840, 912]]}
## Falling leaves start inside the oak's crown (an ellipse) and land on the hill.
const CROWN_C := Vector2(215, 135)
const CROWN_R := Vector2(165, 105)
const LEAF_COLS := [Color(0.31, 0.5, 0.18), Color(0.45, 0.62, 0.22), Color(0.6, 0.72, 0.3), Color(0.24, 0.4, 0.17)]
## Butterflies flutter over the flowers at these spots.
const FLUTTER_HOMES := [Vector2(886, 476), Vector2(318, 500)]
const FLUTTER_COLS := [Color(0.98, 0.97, 0.9), Color(1.0, 0.86, 0.35)]
## A far bird is a 5x3 "v" on the 3x grid, two wing frames.
const FAR_BIRD := [["X...X", ".X.X.", "..X.."], [".....", "XX.XX", "..X.."]]
const FAR_INK := Color(0.2, 0.26, 0.36, 0.85)

var rng := RandomNumberGenerator.new()
var walkers: Array = []     # [{kind, x, dir, t, pause_at, pause_left, paused}]
var birds: Array = []       # [{x, y, vx, t, bob}]
var far_birds: Array = []   # [{x, y, vx, t}]
var leaves: Array = []      # [{x, y, vy, t, sway, freq, col, ground, rest}]
var flutters: Array = []    # [{home, t, sp, col}]
var _next_walker := {"hill": 1.5, "front": 6.0}
var _next_birds := 0.6
var _next_leaf := 0.8
var _t := 0.0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in FLUTTER_HOMES.size():
		flutters.append({"home": FLUTTER_HOMES[i], "t": rng.randf() * 10.0, "sp": rng.randf_range(0.7, 1.1),
				"col": FLUTTER_COLS[i % FLUTTER_COLS.size()]})


## The hill lane's ground height at x.
static func hill_y(x: float) -> float:
	if x <= HILL_PATH[0].x:
		return HILL_PATH[0].y
	for i in range(1, HILL_PATH.size()):
		var a: Vector2 = HILL_PATH[i - 1]
		var b: Vector2 = HILL_PATH[i]
		if x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return HILL_PATH[-1].y


static func lane_y(lane: String, x: float) -> float:
	return FRONT_Y if lane == "front" else hill_y(x)


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## Moves everything on by `delta` seconds (tests call this directly).
func step(delta: float) -> void:
	_t += delta
	_step_walkers(delta)
	_step_birds(delta)
	_step_leaves(delta)
	for f in flutters:
		f["t"] += delta * f["sp"]


func _step_walkers(delta: float) -> void:
	for lane in _next_walker:
		var busy := false
		for w in walkers:
			if CRITTERS[w["kind"]]["lane"] == lane:
				busy = true
		if busy:
			continue
		_next_walker[lane] -= delta
		if _next_walker[lane] <= 0.0:
			_spawn_walker(lane)
	for w in walkers.duplicate():
		var c: Dictionary = CRITTERS[w["kind"]]
		if w["pause_left"] > 0.0:
			w["pause_left"] -= delta
			if w["pause_left"] <= 0.0:
				w["t"] = 0.0
			continue
		w["t"] += delta
		var moving := true
		if c.has("hop"):
			moving = (c["hop"] as Array).has(_frame(w))
		if moving:
			w["x"] += w["dir"] * c["speed"] * delta
		if not w["paused"] and w["pause_at"] != null and (w["x"] - w["pause_at"]) * w["dir"] >= 0.0:
			w["paused"] = true
			w["pause_left"] = rng.randf_range(1.5, 3.5)
			w["t"] = 0.0
		if w["x"] < -140.0 or w["x"] > DESIGN.x + 140.0:
			walkers.erase(w)
			_next_walker[c["lane"]] = rng.randf_range(4.0, 11.0)


func _spawn_walker(lane: String) -> void:
	var kinds := []
	for k in CRITTERS:
		if CRITTERS[k]["lane"] == lane:
			kinds.append(k)
	var kind: String = kinds[rng.randi() % kinds.size()]
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var pause_at = null
	if rng.randf() < 0.6:
		var spots: Array = PAUSE_SPOTS[lane]
		var s: Array = spots[rng.randi() % spots.size()]
		pause_at = rng.randf_range(s[0], s[1])
	walkers.append({"kind": kind, "x": -110.0 if dir > 0.0 else DESIGN.x + 110.0, "dir": dir, "t": 0.0,
			"pause_at": pause_at, "pause_left": 0.0, "paused": false})


func _frame(w: Dictionary) -> int:
	var c: Dictionary = CRITTERS[w["kind"]]
	var n: int = int(c["tex"].get_width() / c["w"])
	if w["pause_left"] > 0.0:
		return 0
	return int(w["t"] * c["fps"]) % n


func _step_birds(delta: float) -> void:
	_next_birds -= delta
	if _next_birds <= 0.0:
		_next_birds = rng.randf_range(5.0, 11.0)
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		if rng.randf() < 0.4:
			var y0 := rng.randf_range(70.0, 210.0)
			var v := rng.randf_range(28.0, 42.0) * dir
			for i in rng.randi_range(2, 5):
				far_birds.append({"x": (-40.0 - i * rng.randf_range(14, 26)) if dir > 0.0 else DESIGN.x + 40.0 + i * rng.randf_range(14, 26),
						"y": y0 + rng.randf_range(-14.0, 14.0), "vx": v, "t": rng.randf() * 2.0})
		else:
			var y1 := rng.randf_range(40.0, 250.0)
			var v1 := rng.randf_range(80.0, 120.0) * dir
			for i in rng.randi_range(1, 3):
				birds.append({"x": (-40.0 - i * rng.randf_range(30, 60)) if dir > 0.0 else DESIGN.x + 40.0 + i * rng.randf_range(30, 60),
						"y": y1 + rng.randf_range(-24.0, 24.0), "vx": v1 * rng.randf_range(0.92, 1.08), "t": rng.randf() * 3.0,
						"bob": rng.randf_range(4.0, 9.0)})
	for list in [birds, far_birds]:
		for b in list.duplicate():
			b["t"] += delta
			b["x"] += b["vx"] * delta
			if b["x"] < -260.0 or b["x"] > DESIGN.x + 260.0:
				list.erase(b)


func _step_leaves(delta: float) -> void:
	_next_leaf -= delta
	if _next_leaf <= 0.0:
		_next_leaf = rng.randf_range(1.2, 3.2)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var p := CROWN_C + Vector2(cos(a) * CROWN_R.x, sin(a) * CROWN_R.y) * r
		leaves.append({"x": p.x, "y": p.y, "vy": rng.randf_range(20.0, 32.0), "t": 0.0,
				"sway": rng.randf_range(10.0, 22.0), "freq": rng.randf_range(1.0, 1.8),
				"col": LEAF_COLS[rng.randi() % LEAF_COLS.size()], "rest": -1.0, "x0": p.x})
	for l in leaves.duplicate():
		l["t"] += delta
		if l["rest"] >= 0.0:
			l["rest"] += delta
			if l["rest"] > 2.0:
				leaves.erase(l)
			continue
		l["y"] += l["vy"] * delta
		l["x0"] += 7.0 * delta  # a light breeze to the right
		l["x"] = l["x0"] + sin(l["t"] * l["freq"] * TAU) * l["sway"]
		if l["y"] >= hill_y(l["x"]) + 6.0:
			l["rest"] = 0.0


func _draw() -> void:
	draw_rect(Rect2(-DESIGN.x, -600, DESIGN.x * 3.0, 600), SKY)
	draw_rect(Rect2(-DESIGN.x, DESIGN.y, DESIGN.x * 3.0, 600), GRASS)
	draw_texture_rect(BG, Rect2(Vector2.ZERO, DESIGN), false)
	# wider than 16:9: the picture mirrored on each side
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect(BG, Rect2(Vector2.ZERO, DESIGN), false)
	draw_set_transform(Vector2(DESIGN.x * 2.0, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(BG, Rect2(Vector2.ZERO, DESIGN), false)
	draw_set_transform(Vector2.ZERO)
	for b in far_birds:
		_draw_far_bird(b)
	for b in birds:
		_draw_bird(b)
	for l in leaves:
		_draw_leaf(l)
	for w in walkers:
		if CRITTERS[w["kind"]]["lane"] == "hill":
			_draw_walker(w)
	for f in flutters:
		_draw_flutter(f)
	for w in walkers:
		if CRITTERS[w["kind"]]["lane"] == "front":
			_draw_walker(w)


func _draw_walker(w: Dictionary) -> void:
	var c: Dictionary = CRITTERS[w["kind"]]
	var tex: Texture2D = c["tex"]
	var fw: float = c["w"]
	var h := float(tex.get_height())
	var f := _frame(w)
	var foot := lane_y(c["lane"], w["x"])
	var pos := Vector2(roundf(w["x"] - fw / 2.0), roundf(foot - h))
	var size := Vector2(fw, h)
	if w["dir"] < 0.0:
		pos.x += fw
		size.x = -fw  # mirrored: walking left
	draw_texture_rect_region(tex, Rect2(pos, size), Rect2(f * fw, 0, fw, h))


func _draw_bird(b: Dictionary) -> void:
	var n := int(BIRD.get_width() / BIRD_W)
	var f := int(b["t"] * BIRD_FPS) % n
	var h := float(BIRD.get_height())
	var y: float = b["y"] + sin(b["t"] * 2.2) * b["bob"]
	var pos := Vector2(roundf(b["x"] - BIRD_W / 2.0), roundf(y - h / 2.0))
	var size := Vector2(BIRD_W, h)
	if b["vx"] < 0.0:
		pos.x += BIRD_W
		size.x = -BIRD_W
	draw_texture_rect_region(BIRD, Rect2(pos, size), Rect2(f * BIRD_W, 0, BIRD_W, h))


func _draw_far_bird(b: Dictionary) -> void:
	var rows: Array = FAR_BIRD[int(b["t"] * 5.0) % 2]
	var o := Vector2(_snap(b["x"]) - 6.0, _snap(b["y"]))
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] == "X":
				draw_rect(Rect2(o + Vector2(c * 3, r * 3), Vector2(3, 3)), FAR_INK)


func _draw_leaf(l: Dictionary) -> void:
	var col: Color = l["col"]
	if l["rest"] >= 0.0:
		col.a = clampf(1.0 - (l["rest"] - 1.0), 0.0, 1.0)
	var o := Vector2(_snap(l["x"]), _snap(l["y"]))
	# it flutters: flat (two pixels wide) half the time, edge-on the rest
	if l["rest"] >= 0.0 or fmod(l["t"] * l["freq"] * 2.0, 1.0) < 0.5:
		draw_rect(Rect2(o, Vector2(6, 3)), col)
	else:
		draw_rect(Rect2(o, Vector2(3, 3)), col)
		draw_rect(Rect2(o + Vector2(3, 3), Vector2(3, 3)), col.darkened(0.15))


func _draw_flutter(f: Dictionary) -> void:
	var t: float = f["t"]
	var home: Vector2 = f["home"]
	var p := home + Vector2(sin(t * 0.9) * 34.0 + sin(t * 2.3) * 8.0, sin(t * 1.3) * 18.0 + cos(t * 3.1) * 5.0)
	var o := Vector2(_snap(p.x), _snap(p.y))
	var col: Color = f["col"]
	if int(t * 9.0) % 2 == 0:
		draw_rect(Rect2(o + Vector2(-3, 0), Vector2(3, 3)), col)
		draw_rect(Rect2(o + Vector2(3, 0), Vector2(3, 3)), col)
	else:
		draw_rect(Rect2(o + Vector2(-3, 3), Vector2(3, 3)), col)
		draw_rect(Rect2(o + Vector2(3, 3), Vector2(3, 3)), col)
	draw_rect(Rect2(o + Vector2(0, 3), Vector2(3, 3)), Color(0.25, 0.2, 0.15))


## Snaps to the background's 3 unit pixel grid.
static func _snap(v: float) -> float:
	return floorf(v / 3.0) * 3.0
