extends "res://tests/support/test_case.gd"
## Look-and-feel numbers Terrence asked for, and the art the 3D die needs.

const DiceDraw := preload("res://game/ui/dice_draw.gd")
const BounceFight := preload("res://logic/bounce/bounce_fight.gd")


func test_split_value_matches_the_drawn_dice() -> bool:
	eq(DiceDraw.split_value(3), [3], "one die up to 6")
	eq(DiceDraw.split_value(7), [4, 3], "7 is 4 and 3")
	eq(DiceDraw.split_value(12), [6, 6], "12 is 6 and 6")
	eq(DiceDraw.split_value(13), [], "a numeral above 12")
	for v in range(1, 13):
		var sum := 0
		for f in DiceDraw.split_value(v):
			check(f >= 1 and f <= 6, "face %d of %d is a die face" % [f, v])
			sum += f
		check(sum == v, "faces of %d add up" % v)
	return true


func test_last_heart_slow_mo_is_20_percent_faster() -> bool:
	# 2026-10-28: was 0.25 of real time, Terrence asked for 20% faster
	var scale: float = BounceFight.load_tuning()["screen"]["last_heart_time_scale"]
	check(is_equal_approx(scale, 0.25 * 1.2), "slow-mo is 0.3, got %s" % scale)
	return true


func test_die_art_exists_for_every_face() -> bool:
	for kind in ["wood", "red"]:
		for f in ["1", "2", "3", "4", "5", "6", "blank"]:
			var path := "res://art/lava/die-%s-%s.png" % [kind, f]
			var tex = load(path)
			check(tex != null and tex.get_size() == Vector2(96, 96), path + " is a 96 px face")
	return true
