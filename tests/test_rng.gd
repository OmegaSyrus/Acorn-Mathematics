extends "res://tests/support/test_case.gd"

const Rng := preload("res://logic/core/rng.gd")


func test_rng_vectors() -> bool:
	for c in vectors("rng.json"):
		var r := Rng.new(c["seed"])
		var u32 := []
		for i in 8:
			u32.append(r.next_u32())
		eq(u32, c["u32"], "u32 seed %d" % c["seed"])
		var d6 := []
		for i in 20:
			d6.append(r.randi_range(1, 6))
		eq(d6, c["d6"], "d6 seed %d" % c["seed"])
		var arr := range(10)
		r.shuffle(arr)
		eq(arr, c["shuffle10"], "shuffle seed %d" % c["seed"])
		eq(r.get_state(), c["state_after"], "state seed %d" % c["seed"])
	return true


func test_state_restore_continues_stream() -> bool:
	var a := Rng.new(99)
	a.next_u32()
	var b := Rng.new(1)
	b.set_state(a.get_state())
	for i in 100:
		check(a.next_u32() == b.next_u32(), "restored stream diverged at %d" % i)
		check(b.get_state() >= 0 and b.get_state() <= Rng.MASK, "state left uint32 range")
	return true
