## Base for test suites: collect failures instead of stopping at the first.
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

var failures := []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Compares by canonical JSON, so int/float and key order never matter.
func eq(actual: Variant, expected: Variant, msg: String) -> void:
	var a := JsonUtil.canonical(actual)
	var e := JsonUtil.canonical(expected)
	if a != e:
		failures.append("%s\n        got      %s\n        expected %s" % [msg, a.left(300), e.left(300)])


func vectors(name: String) -> Array:
	var data = JsonUtil.load_file("res://tests/vectors/" + name)
	check(data != null, "missing vectors " + name)
	return [] if data == null else data["cases"]


func fuzz_count(default_count: int) -> int:
	var env := OS.get_environment("FUZZ_COUNT")
	return env.to_int() if env.is_valid_int() else default_count
