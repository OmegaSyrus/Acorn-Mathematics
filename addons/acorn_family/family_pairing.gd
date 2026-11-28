## Pairing, as a state machine with no network in it (api-v1.md, Pairing):
## start asks for a code, then the tablet polls every 3 s, a little slower
## after the first minute and slower again while offline, until a grown-up
## approves it on their phone or the code runs out (10 minutes).
##
## Times are seconds on any steady clock (family.gd passes its own); tests
## pass their own numbers.
extends RefCounted

enum State { IDLE, STARTING, WAITING, APPROVED, EXPIRED, OFFLINE }

const POLL := 3.0
## After this many polls (about a minute) the wait grows by GROW each time...
const FAST_POLLS := 20
const GROW := 1.5
## ...up to this.
const SLOW_POLL := 10.0
## While offline the wait doubles from POLL up to this.
const OFFLINE_POLL := 30.0

var state := State.IDLE
var pair_id := ""
var code := ""
var qr_url := ""
var expires_at := 0.0
var next_poll_at := 0.0
var polls := 0
var net_failures := 0
## The approved answer ({device_token, family, dev, name, children}).
var approved := {}
## True while a poll is out (family.gd sends one at a time).
var polling := false


func begin() -> void:
	state = State.STARTING
	pair_id = ""
	code = ""
	qr_url = ""
	polls = 0
	net_failures = 0
	approved = {}
	polling = false


## The answer to pair/start. A code means we wait; anything else is offline
## (or the server said no), and the screen offers to try again.
func started(status: int, data: Dictionary, now: float) -> void:
	if status >= 200 and status < 300 and str(data.get("pair_id", "")) != "" and str(data.get("code", "")) != "":
		state = State.WAITING
		pair_id = str(data["pair_id"])
		code = str(data["code"])
		qr_url = str(data["qr_url"]) if data.get("qr_url") is String else ""
		expires_at = now + float(data.get("expires_in", 600))
		next_poll_at = now + POLL
		return
	state = State.OFFLINE


## The answer to one poll. Returns the new state.
func polled(status: int, data: Dictionary, now: float) -> State:
	polling = false
	if state != State.WAITING:
		return state
	polls += 1
	if status == 404:
		# the server forgets a pairing once it ran out (or was handed over)
		state = State.EXPIRED
		return state
	if status < 200 or status >= 300:
		net_failures += 1
		if now >= expires_at:
			state = State.EXPIRED
		next_poll_at = now + poll_delay()
		return state
	net_failures = 0
	match str(data.get("state", "")):
		"approved":
			if str(data.get("device_token", "")) == "":
				state = State.EXPIRED
			else:
				state = State.APPROVED
				approved = data
		"expired":
			state = State.EXPIRED
		_:
			if data.has("expires_in"):
				expires_at = now + float(data["expires_in"])
			if now >= expires_at:
				state = State.EXPIRED
	next_poll_at = now + poll_delay()
	return state


## Seconds until the next poll: 3 s for about a minute, then growing to 10 s;
## doubling to 30 s while polls fail.
func poll_delay() -> float:
	if net_failures > 0:
		return minf(OFFLINE_POLL, POLL * pow(2.0, net_failures))
	if polls < FAST_POLLS:
		return POLL
	return minf(SLOW_POLL, POLL * pow(GROW, polls - FAST_POLLS + 1))


## Time for the next poll.
func due(now: float) -> bool:
	return state == State.WAITING and not polling and now >= next_poll_at


func seconds_left(now: float) -> int:
	return maxi(0, int(ceil(expires_at - now)))


func cancel() -> void:
	state = State.IDLE
	pair_id = ""
	code = ""
	polling = false


## A line for the grown-up, for each state.
func describe(now: float) -> String:
	match state:
		State.STARTING:
			return "Asking for a code..."
		State.WAITING:
			var m := int(ceil(seconds_left(now) / 60.0))
			if net_failures > 0:
				return "Waiting for a grown-up... (no internet right now, still trying)"
			return "Waiting for a grown-up... (the code runs out in %d min)" % m
		State.APPROVED:
			return "Linked!"
		State.EXPIRED:
			return "The code ran out. Show a new one."
		State.OFFLINE:
			return "Can't reach the parent app. Check the Wi-Fi and try again."
	return ""
