## The worlds' moving details (game/ui/ambient.gd, 2026-11-12): the spots
## they sit on are found for every piece of art that uses them, and lie on it.
extends "res://tests/support/test_case.gd"

const Ambient := preload("res://game/ui/ambient.gd")
const WorldTheme := preload("res://game/ui/world_theme.gd")


func _in_art(path: String, kind: String, size: Vector2) -> void:
	var spots: Array = Ambient._spot(path, kind)
	check(not spots.is_empty(), "no %s for %s" % [kind, path])
	for p in spots:
		check(p[0] >= 0 and p[0] < size.x and p[1] >= 0 and p[1] < size.y,
				"%s spot %s off the art %s" % [kind, str(p), path])


func test_every_world_piece_has_its_spots() -> bool:
	_in_art(WorldTheme.get_theme("crystal_mines")["backdrop"], "glints", Vector2(320, 180))
	for c in WorldTheme.get_theme("crystal_mines")["ceiling"]:
		_in_art(c, "tips", Vector2(240, 148))
	_in_art(WorldTheme.get_theme("crystal_mines")["fight_bg"], "glints", Vector2(320, 180))
	_in_art(WorldTheme.get_theme("crystal_mines")["fight_bg"], "lamps", Vector2(320, 180))
	_in_art(WorldTheme.get_theme("lava_caves")["fight_bg"], "lava", Vector2(320, 180))
	check(Ambient._spot(WorldTheme.get_theme("lava_caves")["fight_bg"], "fall").size() == 4, "lavafall span")
	for w in ["lava_caves", "crystal_mines", "bog"]:
		_in_art(WorldTheme.get_theme(w)["treasure"], "glints", Vector2(320, 180))
	return true


## Effects that would draw near the stones' numbers must not be crosses
## (a "+" beside a number reads as a sign): the crossing's glints stay above
## the stone row.
func test_crossing_glints_stay_above_the_stones() -> bool:
	var below := 0
	for p in Ambient._spot(WorldTheme.get_theme("crystal_mines")["backdrop"], "glints"):
		if p[1] * Ambient.PX <= 370.0:
			below += 1
	check(below >= 6, "too few crystal glints above the stone row: %d" % below)
	return true


func test_slots_are_steady() -> bool:
	for i in range(-50, 50):
		var a := Ambient._h(i, 3)
		check(a >= 0.0 and a < 1.0, "hash out of range")
		check(a == Ambient._h(i, 3), "hash not steady")
	return true
