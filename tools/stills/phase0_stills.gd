## Stills for Phase 0 (2026-11-16): each world's miniboss rule in a duel,
## each boss on its own board, a crossing's counter in the world's currency,
## and the shop with every balance.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/phase0_stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const StoreScreen := preload("res://game/store_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

const WORLDS := [
	["lava", "lava_scroll", "lava_caves", "lava_miniboss"],
	["crystal", "crystal_scroll", "crystal_mines", "crystal_miniboss"],
	["bog", "bog_scroll", "bog", "bog_miniboss"],
	["mushroom", "mushroom_scroll", "mushroom_forest", "mushroom_miniboss"],
	["space", "space_scroll", "space", "space_miniboss"],
]

var out_dir := "/tmp"
var stage: Node2D
var save := {"gems": 23, "currencies": {"crystals": 12, "brooches": 31, "leaves": 7, "feathers": 40}, "owned": []}


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	for w in WORLDS:
		await _duel(w)
		await _boss(w)
		await _crossing(w)
	await _store()
	get_tree().quit()


func _duel(w: Array) -> void:
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 2, w[3], false, true)
	stage.add_child(f)
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot(w[0] + "-duel")
	if w[3] == "crystal_miniboss":
		await get_tree().create_timer(FightScreen.FLASH_S * FightScreen.SLOW + 0.8).timeout
		_shot(w[0] + "-duel-dark")
	if w[3] == "bog_miniboss":
		# the king is out; the queen fights on
		f.fight.foes[0]["hearts"] = 0
		f.shown_foe_hearts[0] = 0
		f.foe_gone[0] = 1.0
		f.fight.foe = 1
		await _frames(10)
		_shot(w[0] + "-duel-queen")
	f.queue_free()
	await _frames(2)


func _boss(w: Array) -> void:
	var b := BounceScreen.new()
	b.world_id = w[2]
	b.setup(SeededRng.new(11), 2)
	stage.add_child(b)
	while b.phase != "naming" or not b.choice.active:
		await _frames(1)
	await _frames(20)
	_shot(w[0] + "-boss")
	b.queue_free()
	await _frames(2)


func _crossing(w: Array) -> void:
	var area := Content.area(w[1])
	var run := ScrollRun.new(area, Content.levels()[int(area["grades"][0])], 2)
	var s := ScrollScreen.new()
	s.setup(run, save, false)
	stage.add_child(s)
	await _frames(20)
	_shot(w[0] + "-counter")
	s.queue_free()
	await _frames(2)


func _store() -> void:
	var st := StoreScreen.new()
	st.persist = false
	st.setup(save)
	stage.add_child(st)
	await _frames(20)
	_shot("store-heroes")
	st.tab = "dice"
	await _frames(5)
	_shot("store-dice")
	st.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
