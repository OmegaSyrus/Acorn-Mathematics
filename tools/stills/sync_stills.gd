## Stills of the family sync screens (addons/acorn_family): the Grown-ups
## panel with Family, the Family screen not linked, waiting with a code,
## linked (who is who, the sending switch), picking a child and the unlink
## question, and the rest screen by day and at bedtime. An in-memory server
## (tests/support/family_fake.gd), no network.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/sync_stills.tscn -- --out=/tmp/shots
extends Node2D

const SaveData := preload("res://logic/core/save_data.gd")
const Content := preload("res://logic/core/content.gd")
const GrownUpsScreen := preload("res://game/grownups_screen.gd")
const FamilyScreen := preload("res://game/family_screen.gd")
const RestScreen := preload("res://game/rest_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")
const FamilyNode := preload("res://addons/acorn_family/family.gd")
const Fake := preload("res://tests/support/family_fake.gd")

const DEV := "d_7f3a9c1e04b25d68"

var out_dir := "/tmp"
var stage: Node2D
var roster := [{"id": "p_04a2c9e1f3b7", "nickname": "Bear", "picture": "fox", "guest": false},
		{"id": "p_91c0d2e4a6b8", "nickname": "Wren", "picture": "bunny", "guest": false},
		{"id": "p_0000000000c3", "nickname": "Sam", "picture": "lion", "guest": false},
		{"id": "p_5e5e00a1b2c3", "nickname": "Guest", "picture": "slime_knight", "guest": true}]


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	Ellwynn.offset = stage.position
	var save := SaveData.new_profile("p_04a2c9e1f3b7")

	var g := GrownUpsScreen.new()
	g.setup(save, Content.worlds())
	g.has_pin = true
	stage.add_child(g)
	await _frames(4)
	_shot("sync-grownups")
	g.queue_free()

	var dir := OS.get_temp_dir().path_join("acorn_sync_stills")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var server := Fake.new()
	server.dev = DEV
	server.pair_state = "waiting"
	server.children.append({"child": "c_00000000beef", "nickname": "Wren", "picture": "bunny"})
	var fam := FamilyNode.new()
	fam.base_url = "https://fake.invalid/v1"
	fam.transport = server
	add_child(fam)
	fam.configure({"game": "acorn-math", "dev": DEV, "app": "0.29.0", "code": 48, "roster": func(): return roster}, dir)

	var s := FamilyScreen.new()
	s.setup(fam, roster)
	stage.add_child(s)
	await _frames(4)
	_shot("sync-family-idle")
	fam.start_pairing()
	await _frames(4)
	_shot("sync-family-code")
	server.pair_state = "approved"
	fam.pairing.next_poll_at = 0.0
	await _frames(6)
	fam.set_child("p_04a2c9e1f3b7", "c_9b2f00e1a7c4")
	fam.set_child("p_91c0d2e4a6b8", "new")
	fam.message = ""
	await _frames(4)
	_shot("sync-family-linked")
	fam.set_consent(true)
	await _frames(4)
	_shot("sync-family-sending")
	s.picking = "p_0000000000c3"
	s.view = "pick"
	s._refresh()
	await _frames(4)
	_shot("sync-family-pick")
	s.view = "unlink"
	s._refresh()
	await _frames(4)
	_shot("sync-family-unlink")
	s.queue_free()

	for why in ["daily", "bedtime"]:
		var r := RestScreen.new()
		r.setup(why, "fox")
		stage.add_child(r)
		await _frames(4)
		_shot("sync-rest-" + why)
		r.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
