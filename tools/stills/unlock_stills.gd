## Stills of Phase 6's unlocks: the main menu's Book button, the monster
## book, the store's Level tab, the world map's trophies and "New hero!".
## Uses its own save in memory; the profile file is never written.
##   godot --headless --path . --import
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/unlock_stills.tscn -- --out=/tmp/shots
extends Node2D

const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Store := preload("res://logic/core/store.gd")
const Book := preload("res://logic/core/book.gd")
const MapScreen := preload("res://game/map_screen.gd")
const StoreScreen := preload("res://game/store_screen.gd")
const BookScreen := preload("res://game/book_screen.gd")
const WorldMapScreen := preload("res://game/world_map_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")
const Look := preload("res://game/ui/look.gd")

var out_dir := "/tmp"
var stage: Node2D


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	# Level 1 beaten everywhere (Leo won), Level 2 beaten in three worlds
	var save := SaveData.new_profile("stills")
	save["gems"] = 31
	for w in Content.worlds():
		SaveData.add_mark(save, w["id"], Content.level_id(w["id"], 1))
	for wid in ["lava_caves", "crystal_mines", "bog"]:
		SaveData.add_mark(save, wid, Content.level_id(wid, 2))
	for id in ["blorp", "craggy", "surtling", "lava_miniboss", "knocker", "gem_dwarf", "wispling", "nixie",
			"draugr", "bog_miniboss", "pixie"]:
		Book.record(save, id, 1)
	var heroes := Store.grant_level_rewards(Store.catalog(), save, Content.worlds())
	print("granted ", heroes)
	save["difficulty"] = 2

	var m := MapScreen.new()
	var shown := {1: {"id": 1, "name": "1", "available": true}, 2: {"id": 2, "name": "2", "available": true}}
	m.setup(save, shown, "lava_scroll")
	stage.add_child(m)
	await _frames(20)
	_shot("unlock-0-menu-book-button")
	m.queue_free()

	var b := BookScreen.new()
	b.setup(save)
	stage.add_child(b)
	b.page = 0
	await _frames(10)
	_shot("unlock-1-book-lava")
	b.page = 2
	b.queue_redraw()
	await _frames(4)
	_shot("unlock-2-book-bog")
	b.page = 4
	b.queue_redraw()
	await _frames(4)
	_shot("unlock-3-book-space-empty")
	b.queue_free()

	var st := StoreScreen.new()
	st.persist = false
	st.setup(save)
	stage.add_child(st)
	await _frames(10)
	_shot("unlock-4-store-heroes")
	st.tab = "level"
	st._present({"what": "tab", "id": "level"})
	await _frames(6)
	_shot("unlock-5-store-level-tab")
	st.tab = "dice"
	st._present({"what": "tab", "id": "dice"})
	await _frames(6)
	_shot("unlock-6-store-dice")
	st.queue_free()

	Look.apply(save)
	var w := WorldMapScreen.new()
	w.setup(save, Content.worlds(), -1, 2, ["lion"])
	stage.add_child(w)
	await _frames(70)
	_shot("unlock-7-map-new-hero")
	w.queue_free()
	var w2 := WorldMapScreen.new()
	w2.setup(save, Content.worlds(), -1, 2)
	stage.add_child(w2)
	await _frames(10)
	_shot("unlock-8-map-trophies-level2")
	w2.queue_free()
	var w3 := WorldMapScreen.new()
	w3.setup(save, Content.worlds(), -1, 1)
	stage.add_child(w3)
	await _frames(10)
	_shot("unlock-9-map-trophies-level1")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
