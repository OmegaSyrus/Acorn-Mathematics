## Finds crossing seeds for the demo: replays what the autopilot does (a wrong
## rock on turn 2, one wrong shield in the first fight, otherwise right) and
## prints seeds that meet two or more fights.
##   godot --headless --path . --script tools/demo/find_seed.gd
extends SceneTree

const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Fight := preload("res://logic/fight/fight.gd")
const Monsters := preload("res://logic/fight/monsters.gd")
const Content := preload("res://logic/core/content.gd")


func _init() -> void:
	var area := Content.area("lava_scroll")
	var grades := Content.grades()
	for seed_value in range(1, 400):
		var run := ScrollRun.new(area, grades[1], seed_value)
		var turn := 0
		var fights := 0
		var chests := 0
		while run.phase != ScrollRun.CLEARED and turn < 60:
			if run.phase == ScrollRun.AWAIT_FIGHT:
				fights += 1
				var f := Fight.new(run.rng, 1, run.current_monster(), Monsters.hearts_of(run.current_monster()))
				var first := fights == 1
				while true:
					var i: int = f.attack.answer_index
					if first:
						i = (i + 1) % f.attack.choices.size()
						first = false
					var out := f.choose(i)
					if f.is_over():
						break
					f.next_exchange()
				run.resolve_fight(f.state == Fight.State.WON)
				continue
			var p := run.roll()
			turn += 1
			var pick: int = p["answer_index"]
			if turn == 2:
				var n: int = p["choices"].size()
				pick = (pick + n - 1) % n if pick > 0 else 1
			var o := run.choose(pick)
			if o["result"] == "chest":
				chests += 1
		if fights >= 2 and turn <= 16:
			print("seed %d: turns %d fights %d chests %d" % [seed_value, turn, fights, chests])
	quit()
