## The menu button at the top right of the lava crossing, beside the gems
## (Terrence 2026-11-05). Tapping it pauses the game and opens a small menu:
## "Home" goes back to the main menu (the run is saved after every task, so
## the map's Go button picks it up again) and "Play" closes the menu.
## Escape / Backspace / controller B opens and closes it too.
## Lives above the screen it belongs to and keeps working while the tree is
## paused; everything under it stops, so no tap leaks through to the game.
extends Node2D

signal home

const Pointer := preload("res://game/ui/pointer.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

## Inside what a 4:3 tablet shows (x 120..840).
const BUTTON := Rect2(780, 14, 56, 56)
const PANEL := Rect2(270, 150, 420, 240)
const HOME_RECT := Rect2(300, 250, 170, 110)
const PLAY_RECT := Rect2(490, 250, 170, 110)
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1.0, 0.85, 0.3)

var is_open := false
var _shown := 0.0     # 0..1 fade of the open menu
var _t := 0.0
var _press_on := ""   # which button the finger went down on


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	Beeper.tone(520.0, 0.08)


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	Beeper.tone(660.0, 0.08)


func _exit_tree() -> void:
	if is_open:
		get_tree().paused = false


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, 1.0 if is_open else 0.0, delta * 8.0)
	if Input.is_action_just_pressed("back"):
		if is_open:
			close()
		else:
			open()
	queue_redraw()


func _input(event: InputEvent) -> void:
	var press := Pointer.is_press(event)
	var release := Pointer.is_release(event)
	if not (press or release or Pointer.is_drag(event)):
		return
	var pos := Pointer.local_pos(self, event)
	if not is_open:
		# only the button itself is ours; every other tap belongs to the game
		if press and BUTTON.grow(8).has_point(pos):
			_press_on = "button"
			get_viewport().set_input_as_handled()
		elif release and _press_on == "button":
			_press_on = ""
			get_viewport().set_input_as_handled()
			if BUTTON.grow(8).has_point(pos):
				open()
		return
	# open: the menu swallows every tap
	get_viewport().set_input_as_handled()
	if press:
		_press_on = _hit(pos)
	elif release:
		var on := _hit(pos)
		if on != "" and on == _press_on:
			match on:
				"home":
					close()
					Beeper.good()
					home.emit()
				"play", "button":
					close()
		_press_on = ""


func _hit(pos: Vector2) -> String:
	if HOME_RECT.has_point(pos):
		return "home"
	if PLAY_RECT.has_point(pos):
		return "play"
	if BUTTON.grow(8).has_point(pos):
		return "button"
	return ""


func _draw() -> void:
	# the button: three bars in a fiery box
	RoundBox.fire(self, BUTTON, _t, 14.0, GOLD if is_open else RoundBox.FIRE_RIM)
	for i in 3:
		var y := BUTTON.position.y + 17.0 + i * 11.0
		RoundBox.fill(self, Rect2(BUTTON.position.x + 13, y, BUTTON.size.x - 26, 6), INK, 3.0)
	if _shown <= 0.0:
		return
	var a := _shown
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.55 * a))
	var font := ThemeDB.fallback_font
	var lift := (1.0 - a) * 24.0
	var panel := PANEL
	panel.position.y += lift
	RoundBox.fill(self, panel, Color(0.12, 0.06, 0.08, 0.96 * a), 26.0)
	RoundBox.frame(self, panel, Color(RoundBox.FIRE_RIM, a), 4.0, 26.0)
	_outlined(font, panel.position + Vector2(0, 62), "Menu", panel.size.x, 40, Color(GOLD, a), a)
	var home_r := HOME_RECT
	home_r.position.y += lift
	var play_r := PLAY_RECT
	play_r.position.y += lift
	_button(font, home_r, "Home", Color(0.42, 0.36, 0.33), a)
	_house(home_r.position + Vector2(home_r.size.x / 2.0, 40), Color(INK, a))
	_button(font, play_r, "Play", Color(0.3, 0.55, 0.32), a)
	_triangle(play_r.position + Vector2(play_r.size.x / 2.0, 40), Color(INK, a))


func _button(font: Font, r: Rect2, label: String, col: Color, a: float) -> void:
	var pressed := _press_on == label.to_lower()
	RoundBox.fill(self, r, Color(col.lightened(0.15 if pressed else 0.0), a), 20.0)
	RoundBox.frame(self, r, Color(INK, 0.5 * a), 3.0, 20.0)
	_outlined(font, r.position + Vector2(0, r.size.y - 18), label, r.size.x, 32, Color(INK, a), a)


func _house(c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -2), c + Vector2(0, -26), c + Vector2(26, -2)]), col)
	draw_rect(Rect2(c + Vector2(-18, -4), Vector2(36, 26)), col)
	draw_rect(Rect2(c + Vector2(-6, 8), Vector2(12, 14)), Color(0.42, 0.36, 0.33, col.a))


func _triangle(c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -24), c + Vector2(22, 0), c + Vector2(-16, 24)]), col)


func _outlined(font: Font, at: Vector2, text: String, w: float, size: int, col: Color, a: float) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 7, Color(DARK, a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
