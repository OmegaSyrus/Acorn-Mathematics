extends "res://tests/support/test_case.gd"

const InputGate := preload("res://logic/core/input_gate.gd")


func test_lockout_300ms() -> bool:
	var g := InputGate.new()
	check(not g.accepts(0), "closed before choices appear")
	g.present(1000)
	check(not g.accepts(1000), "a press as choices appear is ignored")
	check(not g.accepts(1299), "a press inside 300 ms is ignored")
	check(g.accepts(1300), "a press at 300 ms counts")
	check(g.is_open(5000), "open later")
	g.close()
	check(not g.accepts(6000), "closed after hiding")
	return true


## Gate 1: twenty presentations with a lingering finger, zero picks. A finger
## that went down before the choices appeared never produces a new press, and
## a press timestamped before present() is never accepted.
func test_twenty_lingering_presses() -> bool:
	var g := InputGate.new()
	var picks := 0
	for i in 20:
		var now := i * 4000
		var finger_down := now - 50 + (i % 5) * 20
		g.present(now)
		if g.accepts(finger_down):
			picks += 1
	check(picks == 0, "lingering finger picked %d times" % picks)
	return true
