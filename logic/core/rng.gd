## Seeded xorshift32 random numbers. The only source of randomness in the
## game logic, so a seed plus the player's inputs replays a run exactly.
## The algorithm is pinned in spec/rng.md and mirrored in tools/ref/rng.py;
## the C++ port must match it bit for bit (see tests/vectors/rng.json).
class_name SeededRng
extends RefCounted

const MASK := 0xFFFFFFFF
const ZERO_SEED_STATE := 0x6D2B79F5
const WARMUP := 8

var state: int = ZERO_SEED_STATE


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	state = seed_value & MASK
	if state == 0:
		state = ZERO_SEED_STATE
	for i in WARMUP:
		next_u32()


## Next raw value in [0, 2^32). Shifts are masked so GDScript's 64-bit ints
## behave like uint32_t.
func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x
	return x


## Inclusive range. Uses plain modulo: the bias over 2^32 is negligible for
## the small ranges a die needs, and modulo is trivial to port.
func randi_range(lo: int, hi: int) -> int:
	assert(hi >= lo)
	return lo + next_u32() % (hi - lo + 1)


## Fisher-Yates, drawing indices from the high end down.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := self.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func get_state() -> int:
	return state


## Restores a saved state exactly (no warm-up), for save and resume.
func set_state(saved: int) -> void:
	state = saved & MASK
	if state == 0:
		state = ZERO_SEED_STATE
