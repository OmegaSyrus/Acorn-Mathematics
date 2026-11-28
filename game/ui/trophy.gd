## The boss trophy (Phase 6, 2026-11-28): a little gold cup, drawn in
## whole pixels like the level marks. A world's boss beaten at a Level puts
## one beside the world on the map, and the monster book shows a row of them
## per world. `scale` makes each art pixel that many units (2 on the map, so
## it reads at arm's length; the art stays on a whole-pixel grid).
extends RefCounted

const DARK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1.0, 0.8, 0.2)
const GOLD_DARK := Color(0.78, 0.5, 0.08)
const GOLD_LIGHT := Color(1.0, 0.96, 0.66)
## An empty socket: the cup's outline in grey, for a Level not won yet.
const EMPTY := Color(0.3, 0.28, 0.31)
const EMPTY_EDGE := Color(0.18, 0.16, 0.19)

## o = edge, # = gold, d = gold shade, h = shine; read row by row.
const ROWS := [
	".oooooooooooo.",
	"oo#h######d#oo",
	"o.o#h#####do.o",
	"o.o#h#####do.o",
	".oo#h#####doo.",
	"...o######o...",
	"....o####o....",
	".....o##o.....",
	"......od......",
	"......od......",
	".....o##o.....",
	"....oo##oo....",
	"...o#####do...",
	"...oooooooo...",
]


static func size(scale := 1) -> Vector2:
	return Vector2(ROWS[0].length(), ROWS.size()) * scale


## The cup with its top left at `at`. won false draws the grey socket.
static func draw(ci: CanvasItem, at: Vector2, won := true, scale := 1, alpha := 1.0) -> void:
	var p := at.round()
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color
			if not won:
				col = EMPTY_EDGE if ch == "o" else EMPTY
			else:
				match ch:
					"o": col = DARK
					"d": col = GOLD_DARK
					"h": col = GOLD_LIGHT
					_: col = GOLD
			col.a *= alpha
			ci.draw_rect(Rect2(p + Vector2(x, y) * scale, Vector2(scale, scale)), col)
