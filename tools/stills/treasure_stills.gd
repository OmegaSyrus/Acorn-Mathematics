## Stills of the 2026-11-06 treasure changes: Red and Green Bolt in the store,
## Red Bolt on the crossing, a chest's gems bursting out and flying to the
## counter, and the gem bucket for beating the dragon. Saves stay in memory.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/treasure_stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
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
	save["gems"] = 12
	Look.apply(save)
	var st := StoreScreen.new()
	st.persist = false
	st.setup(save)
	stage.add_child(st)
	await _frames(20)
	_shot("treasure-1-store-heroes")
	await get_tree().create_timer(0.35).timeout
	for i in st.targets.size():
		if st.targets[i]["what"] == "card" and st.targets[i]["id"] == "bolt_red":
			st.choice._pick(i)
	await _frames(8)
	for i in st.targets.size():
		if st.targets[i]["what"] == "buy":
			st.choice._pick(i)
	await _frames(50)
	_shot("treasure-2-red-bolt-bought")
	st.queue_free()

	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 3)
	var s := ScrollScreen.new()
	s.setup(run, {"gems": 7}, false)
	stage.add_child(s)
	await _frames(20)
	_shot("treasure-3-red-bolt-crossing")
	s.gems_unshown = 2
	s._open_chest(1, 2)
	for at in [0.2, 0.45, 0.7, 1.15, 1.45]:
		while s.gem_fly < at:
			await _frames(1)
		_shot("treasure-4-chest-%03d" % int(at * 100))
	await get_tree().create_timer(1.0).timeout
	s.queue_free()
	await _frames(2)

	Look.hero_id = "bolt_green"
	var b := BounceScreen.new()
	b.setup(SeededRng.new(11), 1)
	b.save = {"gems": 20}
	b.persist = false
	stage.add_child(b)
	while b.phase != "aiming":
		await _frames(1)
	await _frames(10)
	b.phase = "won"
	b._gem_bucket()
	for at in [0.3, 0.9, 1.6, 2.6]:
		while b.bucket_t < at:
			await _frames(1)
		_shot("treasure-5-bucket-%03d" % int(at * 100))
	print("bucket banked: ", b.save["gems"])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
