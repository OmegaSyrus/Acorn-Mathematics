## Root: keeps the 960x540 design space centered in whatever width the
## screen shows (960 on 16:9, 864 on 16:10, 720 on 4:3) and swaps screens.
extends Node2D

const InputSetup := preload("res://game/input_setup.gd")
const Content := preload("res://logic/core/content.gd")
const AreaRun := preload("res://logic/path/area_run.gd")
const SaveStore := preload("res://game/save_store.gd")
const SaveData := preload("res://logic/core/save_data.gd")
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
const DebugScreen := preload("res://game/debug_screen.gd")

const DESIGN := Vector2(960, 540)
const DEFAULT_AREA := "lava_scroll"

var stage: Node2D
var screen: Node2D
var menu: GameMenu
var save: Dictionary
var grades: Dictionary
var debug_on := false
var area_id := DEFAULT_AREA
var play_grade := 1  # the main menu's difficulty (level 1 to 6), for the next area picked on the map
var levels: Dictionary


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
	levels = Content.levels()
	save = SaveStore.read()
	play_grade = clampi(int(save.get("difficulty", 1)), 1, 6)
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
	# the menu's difficulty is the level number, 1 to 6, in every world
	var shown := {}
	for n in range(1, 7):
		shown[n] = {"id": n, "name": "Level %d" % n, "available": true}
	var m := MapScreen.new()
	m.setup(save, shown, area_id)
	m.start.connect(_on_play)
	m.shop.connect(func():
		Ellwynn.menu_tap("shop")
		show_store())
	m.reset_save.connect(_reset_save)
	m.debug.connect(show_debug)
	_swap(m)
	menu.visible = false
	Music.play_menu()
	Ellwynn.menu_enter(save)


## The main menu's Reset, held through its question: a fresh save (gems,
## purchases, marks, the saved run, Ellwynn's intro), then the menu again.
func _reset_save() -> void:
	var fresh := SaveData.new_profile(String(save.get("profile", SaveStore.PROFILE)))
	save.clear()
	save.merge(fresh)
	SaveStore.write(save)
	Ellwynn.stop_voice()
	show_map.call_deferred()


## The Debug screen, from the main menu's Debug button: jump straight to any
## world's crossing, miniboss or boss at any level, or open every world on
## the map. Back returns to the main menu.
func show_debug() -> void:
	var d := DebugScreen.new()
	d.setup(save, Content.worlds())
	d.back.connect(func():
		SaveStore.write(save)
		show_map.call_deferred())
	d.jump.connect(_debug_jump)
	_swap.call_deferred(d)
	menu.visible = false


## A Debug jump: a fresh crossing, duel or boss in that world at that level
## number (any saved run is dropped). What follows plays as usual.
func _debug_jump(to_area: String, level: int, stage: String) -> void:
	area_id = to_area
	play_grade = level
	save["difficulty"] = level
	save["run"] = null
	var area := Content.area(area_id)
	var grade_id := Content.level_id(str(area.get("world", "lava_caves")), level)
	if stage == "":
		_on_start(grade_id, false)
	else:
		_play_level_music()
		menu.visible = true
		_start_stage(area, grade_id, stage)


## The store, from the map's Shop button; Back returns to the map. The menu
## song keeps playing.
func show_store() -> void:
	var st := StoreScreen.new()
	st.setup(save)
	st.back.connect(show_map)
	_swap.call_deferred(st)
	menu.visible = false
	Music.play_menu()


## The main menu's Play: on to the map with the difficulty picked there
## (Terrence 2026-11-07).
func _on_play(grade_id: int, _resume: bool) -> void:
	Ellwynn.menu_tap("play")
	play_grade = grade_id
	SaveStore.write(save)
	show_world_map()


## A world tapped on the map: its saved run picks up again (the crossing, or
## the duel or boss after its door), else a new run at the menu's difficulty
## (or the area's first grade, if it isn't built for that one).
func _enter_area() -> void:
	var saved = save.get("run")
	if saved is Dictionary and saved.get("area") == area_id:
		_on_start(int(saved["grade"]), true)
		return
	var area := Content.area(area_id)
	var grade_id := play_grade
	if area.has("world") and levels.size() > 0:
		# the menu's level number in this world (Lava 1 keeps id 1)
		grade_id = Content.level_id(str(area["world"]), play_grade)
	if area.has("grades") and not area["grades"].has(grade_id) and not area["grades"].is_empty():
		grade_id = int(area["grades"][0])
	_on_start(grade_id, false)


## A level (content/levels.json) or an old graybox grade.
func _grade(id: int) -> Dictionary:
	return levels.get(id, grades.get(id, grades[1]))


## The fight rule and top for a level: its "fight" entry, else the grade itself.
func _fight_of(id: int) -> Dictionary:
	return _grade(id).get("fight", {"grade": id, "top": 0})


func _on_start(grade_id: int, resume: bool) -> void:
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


## The level songs (the lava ones) play in every world until the Crystal
## Mines and the Bog get songs of their own.
func _play_level_music() -> void:
	Music.play_lava()


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
		run = ScrollRun.new(area, _grade(grade_id), data["seed"])
		run.restore(data)
	else:
		run = ScrollRun.new(area, _grade(grade_id), _new_seed())
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
	_unlocked_before = AreaFlow.unlocked_count(save, Content.worlds())
	AreaFlow.enter(save, area, grade_id, stage)
	SaveStore.write(save)
	match stage:
		AreaFlow.DUEL:
			_start_duel(area, grade_id)
		AreaFlow.BOSS:
			_start_boss(area, grade_id)
		_:
			show_world_map.call_deferred(_newly_unlocked(area))


## The miniboss duel. A loss restarts the duel by itself (FightScreen), so
## it only ends in a win, which leads to the boss.
func _start_duel(area: Dictionary, grade_id: int) -> void:
	_play_level_music()
	menu.visible = true
	var f := FightScreen.new()
	var fg := _fight_of(grade_id)
	f.setup(SeededRng.new(_new_seed()), int(fg["grade"]), area["miniboss"], false, true, debug_on)
	f.fight.set_top(int(fg["top"]))
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
	b.setup(SeededRng.new(_new_seed()), int(_grade(grade_id).get("boss_grade", grade_id)), debug_on)
	b.world_id = str(area.get("world", "lava_caves"))
	b.save = save
	b.done.connect(func(won: bool):
		if won:
			_start_stage(area, grade_id, AreaFlow.next_stage(area, AreaFlow.BOSS))
		elif b.to_map:
			show_world_map.call_deferred(-1)
		else:
			_start_boss.call_deferred(area, grade_id))
	_swap.call_deferred(b)


var _unlocked_before := 0


## The world the boss just unlocked (its lock pops off on the map), or -1.
func _newly_unlocked(_area: Dictionary) -> int:
	var now := AreaFlow.unlocked_count(save, Content.worlds())
	return now - 1 if now > _unlocked_before else -1


## The map of the worlds: Play on the main menu opens it, and it follows each
## boss. Tapping an open world plays it; locked worlds wait for the one
## before them to be beaten. The menu button leads back to the main menu.
func show_world_map(just_unlocked := -1) -> void:
	var w := WorldMapScreen.new()
	w.setup(save, Content.worlds(), just_unlocked)
	w.open_world.connect(func(world: Dictionary):
		area_id = world["area"]
		_enter_area())
	_swap(w)
	menu.visible = true
	Music.play_menu()
