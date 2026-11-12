## The level marks on the map and the main menu (2026-11-12): a gold
## "cleared" mark for each level beaten in a world (boss and all), and a
## brighter star beside it when that level's crossing was cleared without
## losing a heart. Drawn in whole units, one art pixel per unit, like the
## characters.
extends RefCounted

const DARK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1.0, 0.8, 0.2)
const GOLD_LIGHT := Color(1.0, 0.95, 0.6)
const EMPTY := Color(0.3, 0.28, 0.31)
const STAR := Color(1.0, 0.98, 0.72)
const STAR_EDGE := Color(1.0, 0.72, 0.1)

## A mark is SIZE x SIZE units; the star beside it is STAR_ROWS wide.
const SIZE := 12
## o = edge, # = fill, h = shine; read row by row.
const STAR_ROWS := [
	"......o......",
	".....o#o.....",
	".....o#o.....",
	"....o#h#o....",
	"ooooo#h##oooo",
	"o###########o",
	".o#########o.",
	"..o#######o..",
	"...o#####o...",
	"...o##o##o...",
	"..o##o.o##o..",
	"..o#o...o#o..",
	"..oo.....oo..",
]


## The cleared mark (top left at `at`): a dark socket, gold when cleared;
## `tint` colors an empty socket's middle (a world's color, dimmed).
static func draw_mark(ci: CanvasItem, at: Vector2, cleared: bool, tint := EMPTY) -> void:
	var p := at.round()
	ci.draw_rect(Rect2(p, Vector2(SIZE, SIZE)), DARK)
	if cleared:
		ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(SIZE - 4, SIZE - 4)), GOLD)
		ci.draw_rect(Rect2(p + Vector2(3, 3), Vector2(2, 2)), GOLD_LIGHT)
	else:
		ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(SIZE - 4, SIZE - 4)), tint)


## The star (top left at `at`), 13 x 13 units.
static func draw_star(ci: CanvasItem, at: Vector2) -> void:
	var p := at.round()
	for y in STAR_ROWS.size():
		var row: String = STAR_ROWS[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col := DARK if ch == "o" else (Color.WHITE if ch == "h" else STAR)
			ci.draw_rect(Rect2(p + Vector2(x, y), Vector2.ONE), col)


## Width of one level's mark and its star side by side.
static func pair_width() -> int:
	return SIZE + 1 + STAR_ROWS[0].length()


## A level's mark with its star to the right (when earned); the star sits
## one unit higher so its points clear the mark.
static func draw_pair(ci: CanvasItem, at: Vector2, cleared: bool, starred: bool, tint := EMPTY) -> void:
	draw_mark(ci, at, cleared, tint)
	if starred:
		draw_star(ci, at + Vector2(SIZE + 1, -1))
