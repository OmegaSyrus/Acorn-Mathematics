## Root: keeps the 960x540 design space centered in whatever width the
## screen shows (960 on 16:9, 864 on 16:10, 720 on 4:3) and swaps screens.
extends Node2D

const InputSetup := preload("res://game/input_setup.gd")
const Content := preload("res://logic/core/content.gd")
const AreaRun := preload("res://logic/path/area_run.gd")
const SaveStore := preload("res://game/save_store.gd")
const MapScreen := preload("res://game/map_screen.gd")
const AreaScreen := preload("res://game/area_screen.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")

const DESIGN := Vector2(960, 540)
const DEFAULT_AREA := "lava_scroll"

var stage: Node2D
var screen: Node2D
var save: Dictionary
var grades: Dictionary
var debug_on := false
var area_id := DEFAULT_AREA


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	stage = Node2D.new()
	add_child(stage)
	get_viewport().size_changed.connect(_layout)
	_layout()
	area_id = _area_from_args()
	grades = Content.grades()
	save = SaveStore.read()
	show_map()


## `godot --path . -- --area=lava_1_fights` plays another area file.
func _area_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--area="):
			var id := arg.substr(7)
			if Content.area_ids().has(id):
				return id
			push_error("unknown area %s, using %s" % [id, DEFAULT_AREA])
	return DEFAULT_AREA


func _layout() -> void:
	var shown := get_viewport_rect().size
	stage.position = ((shown - DESIGN) / 2.0).round()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _swap(next: Node2D) -> void:
	if screen != null:
		if "debug_on" in screen:
			debug_on = screen.get("debug_on")
		screen.queue_free()
	screen = next
	stage.add_child(screen)


func show_map() -> void:
	# A scroll area lists the grades it is built for.
	var area := Content.area(area_id)
	var shown := grades
	if area.has("grades"):
		shown = {}
		for gid in area["grades"]:
			shown[int(gid)] = grades[int(gid)]
	var m := MapScreen.new()
	m.setup(save, shown, area_id)
	m.start.connect(_on_start)
	_swap(m)


func _on_start(grade_id: int, resume: bool) -> void:
	var area := Content.area(area_id)
	if area.get("type") == "scroll":
		_start_scroll(area, grade_id, resume)
		return
	var run: AreaRun
	if resume:
		var data: Dictionary = save["run"]
		run = AreaRun.new(area, grades[grade_id], Content.stickers(), data["seed"])
		run.restore(data)
	else:
		var seed_value := (int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()) & 0xFFFFFFFF
		run = AreaRun.new(area, grades[grade_id], Content.stickers(), seed_value)
		save["run"] = run.to_save()
		SaveStore.write(save)
	var a := AreaScreen.new()
	a.setup(run, save, debug_on)
	a.finished.connect(show_map)
	_swap.call_deferred(a)


func _new_seed() -> int:
	return (int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()) & 0xFFFFFFFF


func _start_scroll(area: Dictionary, grade_id: int, resume: bool) -> void:
	var run: ScrollRun
	if resume:
		var data: Dictionary = save["run"]
		run = ScrollRun.new(area, grades[grade_id], data["seed"])
		run.restore(data)
	else:
		run = ScrollRun.new(area, grades[grade_id], _new_seed())
		save["run"] = run.to_save()
		SaveStore.write(save)
	var s := ScrollScreen.new()
	s.setup(run, save, debug_on)
	s.finished.connect(show_map)
	_swap.call_deferred(s)
