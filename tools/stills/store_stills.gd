## Stills of the store (map button, both tabs, buying the slime, "not yet"),
## and the crossing, a fight and the boss fight with a store hero and dice.
## Uses its own save in memory; the profile file is never written.
##   godot --headless --path . --import
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/store_stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const MapScreen := preload("res://game/map_screen.gd")
const StoreScreen := preload("res://game/store_screen.gd")
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
	var save := SaveData.new_profile("stills")
	save["gems"] = 43

	var m := MapScreen.new()
	m.setup(save, {1: Content.grades()[1]}, "lava_scroll")
	stage.add_child(m)
	await _frames(20)
	_shot("store-0-map")
	m.queue_free()

	var st := _store(save)
	await _frames(20)
	_shot("store-1-heroes")
	await _tap(st, "card", "slime_knight")
	_shot("store-2-buy-picked")
	await _tap(st, "buy", "slime_knight")
	await _frames(6)
	_shot("store-3-bought")
	await _frames(60)
	_shot("store-4-slime-on")
	await _tap(st, "tab", "dice")
	await _frames(10)
	_shot("store-5-dice")
	st.queue_free()

	var poor := SaveData.new_profile("stills")
	poor["gems"] = 12
	Look.apply(poor)
	var st2 := _store(poor)
	await _frames(20)
	await _tap(st2, "card", "slime_knight")
	await _frames(4)
	_shot("store-6-not-yet")
	st2.queue_free()

	# play with the slime and a gem skin (the skin is set directly: it is
	# not for sale yet)
	Look.hero_id = "slime_knight"
	Look.dice_id = "sapphire"
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], _sub_seed(area))
	var s := ScrollScreen.new()
	s.setup(run, {"gems": 6}, false)
	stage.add_child(s)
	await _frames(20)
	s.rolled.emit()
	while not s.choice.active:
		await _frames(1)
	await _frames(30)
	_shot("crossing-slime-sapphire")
	s.queue_free()
	await _frames(2)
	Look.dice_id = "gold"
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 1, "blorp", false, false)
	stage.add_child(f)
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot("fight-slime-gold")
	f.queue_free()
	await _frames(2)
	Look.hero_id = "phoenix"
	var b := BounceScreen.new()
	b.setup(SeededRng.new(11), 1)
	stage.add_child(b)
	while b.phase != "aiming":
		await _frames(1)
	await _frames(20)
	_shot("boss-phoenix")
	get_tree().quit()


func _store(save: Dictionary) -> Node2D:
	var st := StoreScreen.new()
	st.persist = false
	st.setup(save)
	stage.add_child(st)
	return st


## Picks a store target the way a tap does (after the 300 ms lockout).
func _tap(st: Node2D, what: String, id: String) -> void:
	await get_tree().create_timer(0.35).timeout
	for i in st.targets.size():
		if st.targets[i]["what"] == what and st.targets[i]["id"] == id:
			st.choice._pick(i)
			break
	await _frames(8)


## A seed whose first roll takes away, so the red die shows.
func _sub_seed(area: Dictionary) -> int:
	for sd in range(1, 200):
		var r := ScrollRun.new(area, Content.grades()[1], sd)
		if r.roll()["op"] == "sub":
			return sd
	return 2


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
