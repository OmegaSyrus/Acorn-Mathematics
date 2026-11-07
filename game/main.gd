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
const StoreScreen := preload("res://game/store_screen.gd")
const GameMenu := preload("res://game/ui/game_menu.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const WorldMapScreen := preload("res://game/world_map_screen.gd")

const DESIGN := Vector2(960, 540)
const DEFAULT_AREA := "lava_scroll"

var stage: Node2D
var screen: Node2D
var menu: GameMenu
var save: Dictionary
var grades: Dictionary
var debug_on := false
var area_id := DEFAULT_AREA


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	stage = Node2D.new()
	add_child(stage)
	menu = GameMenu.new()
	menu.visible = false
	menu.home.connect(show_map)
	stage.add_child(menu)
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
	Ellwynn.offset = stage.position


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
	if not (next is MapScreen):
		Ellwynn.menu_leave()
	stage.add_child(screen)
	stage.move_child(menu, -1)


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
	m.shop.connect(func():
		Ellwynn.menu_tap("shop")
		show_store())
	_swap(m)
	menu.visible = false
	Music.play_menu()
	Ellwynn.menu_enter(save)


## The store, from the map's Shop button; Back returns to the map. The menu
## song keeps playing.
func show_store() -> void:
	var st := StoreScreen.new()
	st.setup(save)
	st.back.connect(show_map)
	_swap.call_deferred(st)
	menu.visible = false
	Music.play_menu()


func _on_start(grade_id: int, resume: bool) -> void:
	Ellwynn.menu_tap("resume" if resume else "play")
	var area := Content.area(area_id)
	_play_level_music()
	menu.visible = true
	if resume and AreaFlow.is_stage_run(save["run"]):
		_start_stage(area, grade_id, save["run"]["stage"])
		return
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


## Every area so far is in the Lava Caves; other worlds get their own songs.
func _play_level_music() -> void:
	if area_id.begins_with("lava"):
		Music.play_lava()
	else:
		Music.stop()


## `-- --seed=123` makes new runs repeatable (demos, bug reports).
func _new_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.substr(7).to_int() & 0xFFFFFFFF
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
	# through the door: the miniboss, then the boss, then the mini map
	s.finished.connect(func(): _start_stage(area, grade_id, AreaFlow.next_stage(area, "")))
	_swap.call_deferred(s)


## One step after the crossing (AreaFlow): the miniboss duel, the boss fight
## or the mini map. The step is saved before it starts, so the map's "Go"
## (after the app closes) opens the same step again.
func _start_stage(area: Dictionary, grade_id: int, stage: String) -> void:
	AreaFlow.enter(save, area, grade_id, stage)
	SaveStore.write(save)
	match stage:
		AreaFlow.DUEL:
			_start_duel(area, grade_id)
		AreaFlow.BOSS:
			_start_boss(area, grade_id)
		_:
			show_world_map.call_deferred()


## The miniboss duel. A loss restarts the duel by itself (FightScreen), so
## it only ends in a win, which leads to the boss.
func _start_duel(area: Dictionary, grade_id: int) -> void:
	_play_level_music()
	menu.visible = true
	var f := FightScreen.new()
	f.setup(SeededRng.new(_new_seed()), grade_id, area["miniboss"], false, true, debug_on)
	f.done.connect(func(won: bool):
		_start_stage(area, grade_id, AreaFlow.next_stage(area, AreaFlow.DUEL) if won else AreaFlow.DUEL))
	_swap.call_deferred(f)


## The boss fight (Match Bounce). A win (the gem bucket is banked by the
## screen) leads to the mini map; on a loss "Try" fights the boss again and
## "Map" goes to the mini map with the boss still saved for the map's "Go".
func _start_boss(area: Dictionary, grade_id: int) -> void:
	_play_level_music()
	menu.visible = true
	var b := BounceScreen.new()
	b.setup(SeededRng.new(_new_seed()), grade_id, debug_on)
	b.save = save
	b.done.connect(func(won: bool):
		if won:
			_start_stage(area, grade_id, AreaFlow.next_stage(area, AreaFlow.BOSS))
		elif b.to_map:
			show_world_map.call_deferred()
		else:
			_start_boss.call_deferred(area, grade_id))
	_swap.call_deferred(b)


## The mini map of the worlds: tapping an open one goes to its main menu
## (grades, Go, Shop); the rest show a lock until they are built.
func show_world_map() -> void:
	var w := WorldMapScreen.new()
	w.setup(save, Content.worlds())
	w.open_world.connect(func(world: Dictionary):
		area_id = world["area"]
		show_map())
	_swap(w)
	menu.visible = false
	Music.play_menu()
