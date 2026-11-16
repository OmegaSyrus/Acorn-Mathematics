extends RefCounted
## One Match Bounce shot: the ball's flight from the launcher to the floor.
## Pure logic, no nodes, no randomness: the same board, pegs left, ball value,
## rule and aim give the same flight on every machine. The game calls step()
## at a fixed 120 Hz and animates the events it returns; bots and tests call
## run().
##
## Only walls, bumpers, ±1 pegs and LIVE pegs are solid. Every other peg is a
## ghost: the ball passes through and the peg whiffs. A live peg pops on
## touch (the ball bounces off it) and is gone at once.
##
## Physics is plain circles and line segments in the 960x540 design space,
## y down, semi-implicit Euler: v += g dt, then p += v dt, then collisions in
## a fixed order (walls, bumpers, mods, pegs). The C++ port repeats this order.

const BounceRules = preload("res://logic/bounce/bounce_rules.gd")

enum End { NONE, FLOOR, TIMEOUT }

var phys: Dictionary
var board: Dictionary
var rule: String
var target: int
## The ball's die. 0 at Acorn (no ball die).
var ball_value: int
## False when the child named the wrong face: nothing pops this shot.
var named_right: bool

var pos: Vector2
var vel: Vector2
var t := 0.0
var steps := 0
var ended: int = End.NONE

## Indices into board.pegs that are still on the board this shot.
var peg_alive: Array[bool] = []
## Pegs the ball is inside right now (ghosts), so a whiff fires once per pass.
var _inside: Array[bool] = []
var mod_used: Array[bool] = []
var popped: Array[int] = []
var mods_hit: Array[int] = []
var damage := 0
var _mods_pending := 0


## aim_decideg: tenths of a degree from straight down, positive to the right.
func _init(p_phys: Dictionary, p_board: Dictionary, p_peg_alive: Array, p_rule: String,
		p_target: int, p_ball_value: int, p_named_right: bool, aim_decideg: int) -> void:
	phys = p_phys
	board = p_board
	rule = p_rule
	target = p_target
	ball_value = p_ball_value
	named_right = p_named_right
	peg_alive.assign(p_peg_alive)
	for i in peg_alive.size():
		_inside.append(false)
	for m in board["mods"]:
		mod_used.append(false)
	pos = launcher(board)
	vel = aim_dir(aim_decideg, phys) * float(phys["launch_speed"])


static func launcher(p_board: Dictionary) -> Vector2:
	return Vector2(p_board["launcher"][0], p_board["launcher"][1])


static func clamp_aim(aim_decideg: int, p_phys: Dictionary) -> int:
	var m: int = p_phys["max_aim_decideg"]
	return clampi(aim_decideg, -m, m)


static func aim_dir(aim_decideg: int, p_phys: Dictionary) -> Vector2:
	var a := deg_to_rad(clamp_aim(aim_decideg, p_phys) / 10.0)
	return Vector2(sin(a), cos(a))


## Is this peg live for the ball as it is right now?
func is_live(peg_index: int) -> bool:
	return named_right and BounceRules.peg_matches(rule, int(board["pegs"][peg_index]["face"]), ball_value, target)


## One fixed step. Returns the events in it, in order:
##   {"type": "pop", "peg": i, "damage": n}   n includes ±1 combo hearts
##   {"type": "whiff", "peg": i}              the ball ghosted through a peg
##   {"type": "mod", "mod": i, "ball": v}      a ±1 peg changed the ball
##   {"type": "bounce"}                        a wall or bumper
##   {"type": "end", "why": End}
func step() -> Array:
	var events := []
	if ended != End.NONE:
		return events
	var dt: float = phys["dt"]
	var r: float = phys["ball_radius"]
	vel.y += float(phys["gravity"]) * dt
	var max_speed: float = phys["max_speed"]
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	pos += vel * dt
	t += dt
	steps += 1
	for w in board["walls"]:
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		if _hit_point(_closest_on_segment(pos, a, b), r, phys["wall_bounce"]):
			events.append({"type": "bounce"})
	for bm in board["bumpers"]:
		if _hit_circle(Vector2(bm["x"], bm["y"]), float(bm["r"]) + r, phys["bumper_bounce"]):
			events.append({"type": "bounce"})
	var peg_r: float = board["peg_radius"]
	for i in board["mods"].size():
		var m: Dictionary = board["mods"][i]
		if _hit_circle(Vector2(m["x"], m["y"]), peg_r + r, phys["peg_bounce"]) and not mod_used[i]:
			mod_used[i] = true
			if ball_value > 0:
				ball_value = maxi(1, ball_value + int(m["add"]))
				mods_hit.append(i)
				_mods_pending += 1
				events.append({"type": "mod", "mod": i, "ball": ball_value})
	for i in board["pegs"].size():
		if not peg_alive[i]:
			continue
		var p: Dictionary = board["pegs"][i]
		var c := Vector2(p["x"], p["y"])
		var touching := pos.distance_to(c) < peg_r + r
		if touching and is_live(i):
			_hit_circle(c, peg_r + r, phys["peg_bounce"])
			peg_alive[i] = false
			popped.append(i)
			var d := 1 + _mods_pending
			_mods_pending = 0
			damage += d
			events.append({"type": "pop", "peg": i, "damage": d})
		elif touching and not _inside[i]:
			events.append({"type": "whiff", "peg": i})
		_inside[i] = touching
	if pos.y > float(board["floor_y"]) + r:
		ended = End.FLOOR
	elif t >= float(phys["max_shot_seconds"]):
		ended = End.TIMEOUT
	if ended != End.NONE:
		events.append({"type": "end", "why": ended})
	return events


## Runs the shot to the end. Returns every event.
func run() -> Array:
	var all := []
	while ended == End.NONE:
		all.append_array(step())
	return all


func _closest_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + ab * k


## Pushes the ball out of a solid circle and reflects it. True on contact.
func _hit_circle(c: Vector2, reach: float, bounce: float) -> bool:
	var d := pos - c
	var dist := d.length()
	if dist >= reach:
		return false
	var n := d / dist if dist > 0.0001 else Vector2(0, -1)
	pos = c + n * reach
	_reflect(n, bounce)
	return true


## Same against the nearest point of a wall.
func _hit_point(cp: Vector2, r: float, bounce: float) -> bool:
	var d := pos - cp
	var dist := d.length()
	if dist >= r:
		return false
	var n := d / dist if dist > 0.0001 else Vector2(0, -1)
	pos = cp + n * r
	_reflect(n, bounce)
	return true


func _reflect(n: Vector2, bounce: float) -> void:
	var vn := vel.dot(n)
	if vn < 0.0:
		vel -= (1.0 + bounce) * vn * n
