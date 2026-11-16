## Headless test runner. Runs every func test_*() in every tests/**/test_*.gd.
##   godot --headless --path . --script tests/run_tests.gd
## Each test returns true; a script error aborts the method and it returns
## null, which counts as a failure. Exit code 0 when everything passes.
## FUZZ_COUNT (env) sets the fuzz size.
extends SceneTree


func _init() -> void:
	var files := _find("res://tests")
	files.sort()
	var failed := 0
	var ran := 0
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("LOAD FAILED ", path)
			failed += 1
			continue
		var suite = script.new()
		for m in script.get_script_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			var t0 := Time.get_ticks_msec()
			var before: int = suite.failures.size()
			var res = suite.call(method)
			ran += 1
			var new_fails: int = suite.failures.size() - before
			var ms := Time.get_ticks_msec() - t0
			if res != true and new_fails == 0:
				suite.failures.append("did not return true (script error?)")
				new_fails = 1
			if new_fails == 0:
				print("ok    %s %s (%d ms)" % [path.get_file(), method, ms])
			else:
				failed += 1
				print("FAIL  %s %s" % [path.get_file(), method])
				for i in range(before, mini(before + 10, suite.failures.size())):
					print("      ", suite.failures[i])
		if "notes" in suite:
			for n in suite.notes:
				print("      note: ", n)
	print("%d tests, %d failed" % [ran, failed])
	quit(1 if failed > 0 else 0)


func _find(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_find(dir.path_join(d)))
	return out
