## Who may speak now (Phase 3, 2026-11-28). Pure logic, no nodes: the
## crossing and the fights (through game/ui/tutor.gd) ask it before Ellwynn
## says a prompt, an event line or a taught line.
##
## The numbers come first: the right number on a right answer (say_right),
## the count-on or the answer after a wrong one (say_counting / say_answer,
## which wait Ellwynn.ANSWER_DELAY before they speak) and the pip count. A
## line that would start while a number is due or being said waits, and
## never cuts it: any new line stops her, and a stop drops a waiting answer.
## Prompts and event lines also wait while she says anything else, and are
## left out when they would come too late. A taught line waits too, but
## after a while it may cut a cheer (never a number).
## The state is shared (static): a fight inside the crossing and the
## crossing itself both see the numbers the other one started.
extends RefCounted

## How long each kind waits for her to be free before it gives up ("skip")
## or, for a taught line, speaks over a cheer.
const PROMPT_WAIT_S := 4.0
const EVENT_WAIT_S := 3.0
const TEACH_WAIT_S := 6.0
## A taught line gives up after this long if the numbers never finish.
const TEACH_GIVE_UP_S := 12.0
## A beat after a number is due, so its own start isn't raced.
const DUE_PAD_S := 0.25
## A count-on still running keeps the numbers going this much longer (its
## last number has a tail after the count is done).
const COUNT_TAIL_S := 1.5

## Before this (msec) a number is due: nothing may start.
static var due_ms := 0
## Until this (msec) she may be saying a number: nothing may cut her.
static var window_ms := 0


static func reset() -> void:
	due_ms = 0
	window_ms = 0


## A number line was just asked for: say_right (delay 0), say_counting or
## say_answer (delay Ellwynn.ANSWER_DELAY), a pip count (delay 0). len_s is
## about how long it runs once it starts.
static func numbers_said(now_ms: int, delay_s: float, len_s: float) -> void:
	if delay_s > 0.0:
		due_ms = maxi(due_ms, now_ms + int((delay_s + DUE_PAD_S) * 1000.0))
	window_ms = maxi(window_ms, now_ms + int((delay_s + len_s) * 1000.0))


## True when no number is due or being said.
static func numbers_free(now_ms: int, talking: bool, counting: bool) -> bool:
	if counting:
		window_ms = maxi(window_ms, now_ms + int(COUNT_TAIL_S * 1000.0))
		return false
	if now_ms < due_ms:
		return false
	if now_ms < window_ms and talking:
		return false
	return true


## What a waiting line does now: "play", "wait" or "skip". kind is
## "prompt", "event" or "teach"; waited_s how long it has waited.
static func decide(kind: String, waited_s: float, now_ms: int, talking: bool, counting: bool) -> String:
	var cap := PROMPT_WAIT_S
	if kind == "event":
		cap = EVENT_WAIT_S
	elif kind == "teach":
		cap = TEACH_WAIT_S
	if not numbers_free(now_ms, talking, counting):
		if kind == "teach":
			return "skip" if waited_s >= TEACH_GIVE_UP_S else "wait"
		return "skip" if waited_s >= cap else "wait"
	if not talking:
		return "play"
	if waited_s < cap:
		return "wait"
	# she is still saying something that isn't a number
	return "play" if kind == "teach" else "skip"
