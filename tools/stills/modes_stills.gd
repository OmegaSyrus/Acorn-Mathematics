## Stills of the modes (Phase 6, 2026-11-28): the main menu with Arena and
## Bounce locked, just opened ("New!") and seen, the Arena between fights
## (mid-round, won, lost) and the Bounce picker. Own saves in memory.
##   godot --headless --path . --import
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/modes_stills.tscn -- --out=/tmp/shots
extends Node2D

const SaveData := preload("res://logic/core/save_data.gd")
const Book := preload("res://logic/core/book.gd")
const Content := preload("res://logic/core/content.gd")
const MapScreen := preload("res://game/map_screen.gd")
const ArenaRun := preload("res://logic/modes/arena_run.gd")
const ArenaScreen := preload("res://game/arena_screen.gd")
const BouncePickerScreen := preload("res://game/bounce_picker_screen.gd")
const Modes := preload("res://logic/modes/modes.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"
var stage: Node2D


func _ready() -> void:
	InputSetup.register()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	Ellwynn.offset = stage.position
	# the menu: both locked, then both just opened, then both seen
	var fresh := _save()
	await _menu(fresh, "modes-menu-locked")
	var open := _save()
	for id in ["blorp", "surtling", "craggy", "knocker", "svartalf"]:
		Book.record(open, id, 1)
	for w in Content.worlds():
		SaveData.add_mark(open, String(w["id"]), Content.level_id(String(w["id"]), 1))
	await _menu(open, "modes-menu-new")
	Modes.mark_seen(open, Modes.ARENA)
	Modes.mark_seen(open, Modes.BOUNCE)
	await _menu(open, "modes-menu-open")
	Ellwynn.menu_leave()
	# the Arena between fights: two won, hearts 2 of 3
	var run := ArenaRun.new(Book.arena_monsters(open), 2, 3)
	run.resolve(true, 3)
	run.resolve(true, 2)
	await _show(_arena(run, 0), "modes-arena")
	var lost := ArenaRun.new(Book.arena_monsters(open), 2, 4)
	lost.resolve(true, 2)
	lost.resolve(true, 1)
	lost.resolve(true, 1)
	lost.resolve(false, 0)
	await _show(_arena(lost, 0), "modes-arena-lost")
	var won := ArenaRun.new(Book.arena_monsters(open), 2, 5)
	for i in ArenaRun.ROUND_FIGHTS:
		won.resolve(true, 2)
	await _show(_arena(won, won.reward(open)), "modes-arena-won")
	# the Bounce picker: every boss beaten
	var p := BouncePickerScreen.new()
	p.setup(open)
	await _show(p, "modes-bounce-picker")
	var one := _save()
	SaveData.add_mark(one, "lava_caves", 1)
	var p1 := BouncePickerScreen.new()
	p1.setup(one)
	await _show(p1, "modes-bounce-picker-one")
	get_tree().quit()


func _save() -> Dictionary:
	var s := SaveData.new_profile("stills")
	s["ellwynn_intro_seen"] = true
	s["gems"] = 12
	return s


func _arena(run: ArenaRun, paid: int) -> Node2D:
	var a := ArenaScreen.new()
	a.setup(run, paid)
	return a


func _menu(save: Dictionary, name: String) -> void:
	var m := MapScreen.new()
	var shown := {}
	for n in range(1, 7):
		shown[n] = {"id": n, "name": "Level %d" % n, "available": true}
	m.setup(save, shown, "lava_scroll")
	m.player = {"nickname": "Robin", "picture": "fox"}
	await _show(m, name, true)


func _show(n: Node2D, name: String, menu := false) -> void:
	stage.add_child(n)
	if menu:
		Ellwynn.menu_enter(n.save)
	await _frames(12)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	n.queue_free()
	await _frames(2)


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
