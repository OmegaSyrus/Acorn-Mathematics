extends SceneTree
## Runs every tests/fight/test_*.gd headless:
##   godot --headless --path <project> --script res://tests/fight/run_fight_tests.gd
## Exit code 0 when everything passes.

const DIR := "res://tests/fight/"


func _init() -> void:
	var failed := 0
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(DIR + file)
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			suite.notes.clear()
			var t0 := Time.get_ticks_msec()
			var finished = suite.call(name)
			var ms := Time.get_ticks_msec() - t0
			if finished != true:
				suite.failures.append("stopped early (script error above)")
			if suite.failures.is_empty():
				print("PASS %s.%s (%d ms)" % [file.get_basename(), name, ms])
			else:
				failed += 1
				print("FAIL %s.%s" % [file.get_basename(), name])
				for f in suite.failures.slice(0, 10):
					print("    ", f)
			for n in suite.notes:
				print("    ", n)
	print("fight tests: %s" % ("all passed" if failed == 0 else "%d failed" % failed))
	quit(0 if failed == 0 else 1)
