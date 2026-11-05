## The menu button at the top right, beside the gems (Terrence 2026-11-05).
## Tapping it pauses the game and opens a small menu: "Main Menu" goes back
## to the main menu (a crossing in progress stays saved, so "Go" there picks
## it up again), "Play" closes the menu. Lives in the 960x540 design space,
## above every screen; main.gd shows it while a level is being played.
extends Node2D

signal home

const Pointer := preload("res://game/ui/pointer.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

const SIZE := 52.0
const MARGIN := 8.0
## Extra tap area round the button, so a small finger still hits it.
const TAP_PAD := 14.0
const PANEL := Rect2(300, 120, 360, 300)
const HOME_RECT := Rect2(340, 196, 280, 88)
const PLAY_RECT := Rect2(340, 302, 280, 88)
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)

var is_open := false
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100


## Top right of what the screen shows (x 840 on a 4:3 tablet, 912 on 16:10,
## 960 on 16:9), so it always sits in the corner. Screens put the gems just
## left of it.
static func button_rect(vp: Viewport) -> Rect2:
	var shown_w := vp.get_visible_rect().size.x
	var right := minf(960.0, 480.0 + shown_w / 2.0) - MARGIN
	return Rect2(right - SIZE, MARGIN, SIZE, SIZE)


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	# timers made with create_timer keep running while paused; this stops them
	Engine.time_scale = 0.0
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var press := Pointer.is_press(event)
	if is_open:
		# the menu takes every tap while it is up
		if press or Pointer.is_release(event) or Pointer.is_drag(event):
			get_viewport().set_input_as_handled()
		if not press:
			return
		var pos := Pointer.local_pos(self, event)
		if HOME_RECT.has_point(pos):
			close()
			home.emit()
		elif PLAY_RECT.has_point(pos) or not PANEL.has_point(pos):
			close()
		return
	if press and button_rect(get_viewport()).grow(TAP_PAD).has_point(Pointer.local_pos(self, event)):
		get_viewport().set_input_as_handled()
		open()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	_draw_button(button_rect(get_viewport()))
	if not is_open:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.6))
	RoundBox.fire(self, PANEL, _t, 24.0)
	_label(font, Vector2(PANEL.position.x, PANEL.position.y + 54), PANEL.size.x, "Menu", 40)
	RoundBox.fill(self, HOME_RECT, Color(0.42, 0.36, 0.33), 18.0)
	_label(font, HOME_RECT.position + Vector2(0, 58), HOME_RECT.size.x, "Main Menu", 40)
	RoundBox.fill(self, PLAY_RECT, Color(0.2, 0.62, 0.3), 18.0)
	_label(font, PLAY_RECT.position + Vector2(0, 58), PLAY_RECT.size.x, "Play", 40)


## A round dark button with three bars, in the fiery boxes' rim colour.
func _draw_button(r: Rect2) -> void:
	RoundBox.fill(self, r, Color(0.12, 0.05, 0.07, 0.9), 14.0)
	RoundBox.frame(self, r, RoundBox.FIRE_RIM, 3.0, 14.0)
	for k in 3:
		var y := r.position.y + 15.0 + k * 11.0
		RoundBox.fill(self, Rect2(r.position.x + 13, y, r.size.x - 26, 6), INK, 3.0)


func _label(font: Font, at: Vector2, w: float, text: String, size: int) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 7, DARK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, INK)
