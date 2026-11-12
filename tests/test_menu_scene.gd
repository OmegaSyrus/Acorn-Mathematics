## The main menu's oak hill: art strips line up, the lanes are continuous,
## and over a long run animals and birds come and go without piling up.
extends "res://tests/support/test_case.gd"

const MenuScene := preload("res://game/ui/menu_scene.gd")


func test_strips_and_grid() -> bool:
	var bg: Texture2D = MenuScene.BG
	eq([bg.get_width(), bg.get_height()], [320, 180], "backgrounds are 320x180 drawn at 3x")
	for k in MenuScene.CRITTERS:
		var c: Dictionary = MenuScene.CRITTERS[k]
		var tex: Texture2D = c["tex"]
		check(tex.get_width() % int(c["w"]) == 0, "%s strip is whole frames of %d" % [k, c["w"]])
		check(tex.get_width() / int(c["w"]) >= 4, "%s has a walk cycle" % k)
		check(tex.get_height() <= 64, "%s is a small 1:1 critter" % k)
	check(MenuScene.BIRD.get_width() % MenuScene.BIRD_W == 0, "bird strip is whole frames")
	return true


func test_hill_lane_is_continuous() -> bool:
	var last := MenuScene.hill_y(-200.0)
	for x in range(-200, 1200, 2):
		var y := MenuScene.hill_y(float(x))
		check(absf(y - last) < 3.0, "hill lane jumps at x %d" % x)
		check(y > 380.0 and y < 480.0, "hill lane stays on the grass at x %d" % x)
		last = y
	return true


func test_long_run_comes_and_goes() -> bool:
	var s := MenuScene.new(11)
	var seen := {}
	var bird_seen := 0
	var most := 0
	for i in 30 * 300:  # five minutes at 30 fps
		s.step(1.0 / 30.0)
		for w in s.walkers:
			seen[w["kind"]] = true
		bird_seen = maxi(bird_seen, s.birds.size() + s.far_birds.size())
		most = maxi(most, s.walkers.size() + s.birds.size() + s.far_birds.size() + s.leaves.size())
	for k in MenuScene.CRITTERS:
		check(seen.has(k), "%s came by in five minutes" % k)
	check(bird_seen > 0, "birds flew over")
	check(most < 40, "things leave again (most at once %d)" % most)
	var lanes := {}
	for w in s.walkers:
		var lane: String = MenuScene.CRITTERS[w["kind"]]["lane"]
		check(not lanes.has(lane), "one walker per lane at a time")
		lanes[lane] = true
	s.free()
	return true
