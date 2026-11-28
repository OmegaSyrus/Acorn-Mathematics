## Ellwynn's voice on the crossing and in fights, and the taught first turn
## (Phase 3, 2026-11-28): a node the crossing and the fight screen each add.
##   - prompt(), event(), teach(): lines said through Ellwynn when she is
##     free (logic/core/voice_turns.gd), so they never cut a number. Lines
##     wait in turn; one that comes too late is left out. Nothing here waits
##     for her: input is never held up by a line.
##   - begin(id, target, point): a taught step (logic/core/first_turn.gd).
##     For a child who hasn't had it, a pointing hand and a glow show on the
##     target until the screen calls finish(id), and her line is said once.
##     A child already taught gets nothing: begin() is false.
##   - replay(): a tap on the talk box says the last prompt again.
## Drawn in the 960x540 design space of the screen it is added to. The hand
## is pixel art made in code, 1 art pixel = 1 unit, moved in whole units and
## turned only by quarter turns, so it stays crisp.
extends Node2D

signal step_done(id: String)

const FirstTurn := preload("res://logic/core/first_turn.gd")
const VoiceTurns := preload("res://logic/core/voice_turns.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

const GLOW := Color(1.0, 0.92, 0.3)
## The hand: where its finger tip is in the image, and its colours.
const HAND_W := 38
const HAND_H := 54
const TIP_X := 13
const SKIN := Color(1.0, 0.85, 0.68)
const SKIN_SHADE := Color(0.88, 0.64, 0.5)
const SKIN_LIGHT := Color(1.0, 0.95, 0.85)
const CUFF := Color(0.36, 0.62, 0.95)
const CUFF_SHADE := Color(0.22, 0.4, 0.72)
const OUTLINE := Color(0.07, 0.04, 0.08)
## The tap: every TAP_S the hand presses this far toward the target.
const TAP_S := 1.1
const TAP_PX := 8.0
## A sweep along a row (stones, shields): one way in this long.
const SWEEP_S := 1.8
## The 4:3 band every tablet shows.
const SAFE_LEFT := 120.0
const SAFE_RIGHT := 840.0

## The child's save (taught marks); {} uses Ellwynn's (Ellwynn.use_save).
var save: Dictionary = {}
var steps: FirstTurn
var _queue: Array = []        # [{kind, id, valid, waited}]
var _target := Callable()     # -> Rect2 (empty: nothing to point at yet)
var _point := "up"            # up, down, left, right, or sweep_up / sweep_down
var _glow := true
var _hand_off := Vector2.ZERO  # the finger tip moved from where it would point
var _t := 0.0
var _hand: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	steps = FirstTurn.new(func(id: String) -> bool: return Ellwynn.was_taught(id, save))
	_hand = ImageTexture.create_from_image(hand_image())


# --- lines -----------------------------------------------------------------

## A talk box prompt (P cues): said when she is free, remembered for a tap
## on the talk box even when it had to be left out.
func prompt(id: String, valid := Callable()) -> void:
	_add("prompt", id, valid)


## An event line (W, C, F, R, D, N ... cues): said when she is free, or not
## at all if that takes too long.
func event(id: String, valid := Callable()) -> void:
	_add("event", id, valid)


## A once-per-child line (T, N cues) with no hint: said once when she is
## free (Ellwynn.teach marks it), or kept for next time if it never fits.
func teach(id: String, valid := Callable()) -> void:
	if Ellwynn.was_taught(id, save):
		return
	_add("teach", id, valid)


## True when this child has had that taught line.
func taught(id: String) -> bool:
	return Ellwynn.was_taught(id, save)


## A number line was just asked for (say_right, say_counting, say_count):
## nothing starts or cuts in until it is said.
func numbers(delay_s: float, len_s: float) -> void:
	VoiceTurns.numbers_said(Time.get_ticks_msec(), delay_s, len_s)


func numbers_free() -> bool:
	return VoiceTurns.numbers_free(Time.get_ticks_msec(), Ellwynn.is_talking(), Ellwynn.is_counting())


## The talk box was tapped: the last prompt again (never over a number).
func replay() -> void:
	if numbers_free():
		Ellwynn.replay_prompt()


func _add(kind: String, id: String, valid: Callable) -> void:
	_queue.append({"kind": kind, "id": id, "valid": valid, "waited": 0.0})


func _run_queue(delta: float) -> void:
	while not _queue.is_empty():
		var q: Dictionary = _queue[0]
		var valid: Callable = q["valid"]
		if valid.is_valid() and not bool(valid.call()):
			_queue.pop_front()
			continue
		q["waited"] = float(q["waited"]) + delta
		var what := VoiceTurns.decide(String(q["kind"]), float(q["waited"]), Time.get_ticks_msec(),
				Ellwynn.is_talking(), Ellwynn.is_counting())
		if what == "wait":
			return
		_queue.pop_front()
		var id := String(q["id"])
		if what == "skip":
			if q["kind"] == "prompt":
				Ellwynn.last_prompt = Ellwynn.resolve(id)
			continue
		match String(q["kind"]):
			"prompt":
				Ellwynn.prompt(id)
			"event":
				Ellwynn.cue_play(id)
			"teach":
				if Ellwynn.teach(id, save):
					steps.line_said(id)
		# one line a frame: the next one waits until she is talking
		return


# --- taught steps ----------------------------------------------------------

## A taught step starts: for a child who hasn't had it, the hint shows on
## target() (a Rect2 in this node's space, re-read every frame; empty hides
## it) and the line is said when she is free. point: where the finger
## points (up: the hand sits under the target; down, left, right), or
## sweep_up / sweep_down to run along a row without resting on any one
## (stones and shields: never show the answer). auto_after: the step ends
## by itself this long after the line (T3, nothing to tap). glow: a pulsing
## frame round the target. hand_off moves the finger tip (whole units).
## False when this child already knows it: no hint, no line.
func begin(id: String, target: Callable, point := "up", auto_after := -1.0, glow := true,
		hand_off := Vector2.ZERO) -> bool:
	if steps.is_on(id):
		return true
	if steps.taught(id):
		return false
	if steps.current != "":
		finish(steps.current)
	if not steps.begin(id, auto_after):
		return false
	_target = target
	_point = point
	_glow = glow
	_hand_off = hand_off.round()
	_queue = _queue.filter(func(q): return q["kind"] != "prompt")
	_add("teach", id, func() -> bool: return steps.is_on(id))
	queue_redraw()
	return true


func is_on(id: String) -> bool:
	return steps != null and steps.is_on(id)


## Moves the hint of the step being taught (T9: from the shields to Go).
func retarget(id: String, target: Callable, point: String) -> void:
	if is_on(id):
		_target = target
		_point = point
		_hand_off = Vector2.ZERO


## The child did the step: the hint goes, and it is marked taught even if
## the line hadn't been said yet (they did it anyway).
func finish(id: String) -> void:
	if steps == null or not steps.finish(id):
		return
	Ellwynn.mark_taught(id, save)
	_target = Callable()
	queue_redraw()
	step_done.emit(id)


func _process(delta: float) -> void:
	_t += delta
	_run_queue(delta)
	if steps.current != "":
		var id := steps.current
		match steps.tick(delta, Ellwynn.is_talking() or not _queue.is_empty()):
			"replay":
				_add("event", id, func() -> bool: return steps.is_on(id))
			"done":
				finish(id)
		queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if steps == null or steps.current == "" or not _target.is_valid():
		return
	var r = _target.call()
	if not r is Rect2 or not (r as Rect2).has_area():
		return
	var rect: Rect2 = r
	if _glow:
		var a := 0.45 + 0.45 * sin(_t * 5.0)
		RoundBox.frame(self, rect.grow(8.0), Color(OUTLINE, 0.6 * a), 7.0, 18.0)
		RoundBox.frame(self, rect.grow(8.0), Color(GLOW, a), 4.0, 18.0)
	var tip := Vector2.ZERO
	var dir := _point
	var along := 0.0
	if _point.begins_with("sweep"):
		dir = _point.substr(6)
		var u := fmod(_t / SWEEP_S, 2.0)
		along = u if u <= 1.0 else 2.0 - u
		along = along * along * (3.0 - 2.0 * along)  # eased at the ends
	var press := _tap_offset()
	# keep the hand inside what a 4:3 tablet shows (x 120..840)
	if dir == "left" and rect.end.x + 4.0 + HAND_H > SAFE_RIGHT:
		dir = "right"
	elif dir == "right" and rect.position.x - 4.0 - HAND_H < SAFE_LEFT:
		dir = "left"
	match dir:
		"up":
			var x := lerpf(rect.position.x + 24.0, rect.end.x - 24.0, along) if _point.begins_with("sweep") else rect.get_center().x
			tip = Vector2(x, rect.end.y + 4.0 - press)
		"down":
			var x := lerpf(rect.position.x + 24.0, rect.end.x - 24.0, along) if _point.begins_with("sweep") else rect.get_center().x
			tip = Vector2(x, rect.position.y - 4.0 + press)
		"left":
			tip = Vector2(rect.end.x + 4.0 - press, rect.get_center().y)
		_:
			tip = Vector2(rect.position.x - 4.0 + press, rect.get_center().y)
	draw_hand(self, (tip + _hand_off).round(), dir)


## The tap: a quick press toward the target and back, in whole units.
func _tap_offset() -> float:
	var u := fmod(_t, TAP_S) / TAP_S
	if u < 0.12:
		return roundf(TAP_PX * u / 0.12)
	if u < 0.3:
		return roundf(TAP_PX * (1.0 - (u - 0.12) / 0.18))
	return 0.0


## Draws the hand with its finger tip at tip, pointing dir (up, down, left,
## right): quarter turns only, so every art pixel stays one unit.
func draw_hand(ci: CanvasItem, tip: Vector2, dir: String) -> void:
	var rot := 0.0
	match dir:
		"down":
			rot = PI
		"left":
			rot = -PI / 2.0
		"right":
			rot = PI / 2.0
	ci.draw_set_transform(tip.round(), rot, Vector2.ONE)
	ci.draw_texture(_hand, Vector2(-TIP_X, 0))
	ci.draw_set_transform(Vector2.ZERO)


## The pointing hand, finger up, its tip at (TIP_X, 0): a 1-unit pixel image
## built from a few rounded boxes, with a 2-pixel dark outline, a light edge
## down the finger, shade on the right and the creases of the folded fingers.
static func hand_image() -> Image:
	var img := Image.create(HAND_W, HAND_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o := Vector2i(2, 2)  # the outline's room
	var shapes := [
		[Rect2i(7, 0, 10, 28), 4, "skin"],    # the finger
		[Rect2i(3, 18, 29, 25), 6, "skin"],   # the fist
		[Rect2i(0, 25, 10, 12), 4, "skin"],   # the thumb
		[Rect2i(6, 41, 23, 8), 2, "cuff"],    # the sleeve
	]
	var kind := {}
	for y in HAND_H:
		for x in HAND_W:
			var p := Vector2i(x, y) - o
			for s in shapes:
				if _in_round(p, s[0], s[1]):
					kind[Vector2i(x, y)] = s[2]
	for y in HAND_H:
		for x in HAND_W:
			var at := Vector2i(x, y)
			if kind.has(at):
				var p := at - o
				var c: Color = SKIN
				if kind[at] == "cuff":
					c = CUFF_SHADE if p.y >= 46 or p.x >= 25 else CUFF
				elif p.y < 18 and p.x <= 8:
					c = SKIN_LIGHT        # light down the finger's left edge
				elif p.x >= 28 or (p.y < 18 and p.x >= 15):
					c = SKIN_SHADE        # shade on the right
				elif p.y >= 20 and p.y <= 40 and p.x >= 17 and p.x <= 29 and (p.y == 27 or p.y == 34):
					c = SKIN_SHADE        # the folded fingers' creases
				elif p.x == 16 and p.y >= 19 and p.y <= 26:
					c = SKIN_SHADE        # between the finger and the fist
				elif p.y >= 1 and p.y <= 3 and p.x >= 10 and p.x <= 13:
					c = SKIN_LIGHT        # the nail
				img.set_pixel(x, y, c)
				continue
			# the outline: two pixels round the shape
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if kind.has(at + Vector2i(dx, dy)):
						near = true
			if near:
				img.set_pixel(x, y, OUTLINE)
	return img


static func _in_round(p: Vector2i, r: Rect2i, rad: int) -> bool:
	if not r.has_point(p):
		return false
	var cx := clampi(p.x, r.position.x + rad, r.end.x - 1 - rad)
	var cy := clampi(p.y, r.position.y + rad, r.end.y - 1 - rad)
	var dx := float(p.x - cx)
	var dy := float(p.y - cy)
	return dx * dx + dy * dy <= float(rad * rad) + 0.5
