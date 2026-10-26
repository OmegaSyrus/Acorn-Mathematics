extends "res://tests/fight/fight_test_base.gd"
## The Godot fight code must match the Python reference exactly
## (tests/fight/ref/fight_ref.py). The C++ port checks the same file.

const AttackGen = preload("res://logic/fight/attack_gen.gd")
const Fight = preload("res://logic/fight/fight.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const VECTORS := "res://tests/fight/vectors/fights.json"


func _load() -> Dictionary:
	var text := FileAccess.get_file_as_string(VECTORS)
	var data = JSON.parse_string(text)
	check(data is Dictionary, "could not read " + VECTORS)
	return data if data is Dictionary else {}


func test_attacks_match_reference() -> bool:
	for case in _load().get("attacks", []):
		var rng = SeededRng.new(int(case.seed))
		for i in case.attacks.size():
			var want: Dictionary = case.attacks[i]
			var got: Dictionary = AttackGen.generate(rng, int(case.grade)).to_dict()
			for key in ["kind", "dice", "target", "answer", "choices", "answer_index"]:
				if not check(_same(got[key], want[key]), "grade %d seed %d attack %d: %s is %s, reference %s" % [case.grade, case.seed, i, key, str(got[key]), str(want[key])]):
					return true
		check(rng.get_state() == int(case.state_after), "grade %d seed %d: RNG state differs after 25 attacks" % [case.grade, case.seed])
	return true


func test_fights_match_reference() -> bool:
	for case in _load().get("fights", []):
		var grade := int(case.grade)
		var hearts := int(case.hearts)
		var rng = SeededRng.new(500 + grade)
		var f = Fight.new(rng, grade, "test", hearts, case.first_strike)
		for i in case.taps.size():
			var out: Dictionary = f.choose(int(case.taps[i]))
			var got := [int(case.taps[i]), out.right, out.hero_hearts, out.monster_hearts, out.state]
			if not check(_same(got, case.log[i]), "grade %d hearts %d tap %d: %s, reference %s" % [grade, hearts, i, str(got), str(case.log[i])]):
				break
			if f.is_over():
				f = Fight.new(rng, grade, "test", hearts, case.first_strike)
			else:
				f.next_exchange()
		check(rng.get_state() == int(case.state_after), "grade %d hearts %d: RNG state differs" % [grade, hearts])
	return true


## JSON numbers come back as floats; compare by value.
func _same(a, b) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is bool or b is bool:
		return bool(a) == bool(b)
	return float(a) == float(b)
