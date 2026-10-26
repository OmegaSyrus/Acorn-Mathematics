## The 300 ms lockout after choices appear (plan section 12). Times are in
## milliseconds from any monotonic clock. The UI also picks only on a fresh
## press, never on a release, so a finger left resting on the screen from the
## previous task can't pick.
extends RefCounted

const LOCKOUT_MS := 300

var shown_at := -1


func present(now_ms: int) -> void:
	shown_at = now_ms


func close() -> void:
	shown_at = -1


func is_open(now_ms: int) -> bool:
	return shown_at >= 0 and now_ms - shown_at >= LOCKOUT_MS


## A press counts only if it began after the lockout ended.
func accepts(press_ms: int) -> bool:
	return shown_at >= 0 and press_ms - shown_at >= LOCKOUT_MS
