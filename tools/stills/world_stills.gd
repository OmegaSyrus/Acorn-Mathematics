## Stills of the Crystal Mines and the Bog (2026-11-08): each crossing (rolled,
## a monster, a wrong stone going down), a fight with each monster, the duel
## and the boss.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/world_stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

const WORLDS := {
	"crystal": ["crystal_scroll", "crystal_mines", ["knocker", "svartalf", "gem_dwarf", "crystal_miniboss"]],
	"bog": ["bog_scroll", "bog", ["wispling", "nixie", "tiddy_mun", "draugr", "bog_miniboss"]],
	"space": ["space_scroll", "space", ["star_squirrel", "moon_hobgoblin", "fenrir_pup", "space_miniboss"]],
}

var out_dir := "/tmp"


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	for key in WORLDS:
		if only != "" and key != only:
			continue
		var w: Array = WORLDS[key]
		var run := ScrollRun.new(Content.area(w[0]), Content.levels().get(int(Content.area(w[0])["grades"][0]), Content.grades()[1]) if key == "space" else Content.grades()[1], 2)
		var s := ScrollScreen.new()
		s.setup(run, {"gems": 6}, false)
		stage.add_child(s)
		await _frames(20)
		s.rolled.emit()
		while not s.choice.active:
			await _frames(1)
		await _frames(30)
		_shot(key + "-walk")
		s.choice.close()
		var mpos := -1
		for at in range(1, s.run.length()):
			if s.run.space_at(at).get("type") == "monster":
				mpos = at
				break
		s._place_hero(mpos)
		s.revealed = mpos
		s.reveal = 1.0
		s.bubble = "Fight!"
		s._hide_dice()
		await _frames(30)
		_shot(key + "-enemy")
		# a wrong stone going down with the dragon on it
		s.revealed = -1
		s.bubble = "Oops!"
		s._place_hero(mpos + 1)
		s.sink_space = mpos + 1
		s.worried = 1.0
		s.rock_sink = 0.55
		s.hero_sink = 0.5
		await _frames(10)
		_shot(key + "-wrong")
		s.queue_free()
		await _frames(2)
		for id in w[2]:
			var f := FightScreen.new()
			f.setup(SeededRng.new(78), 1, id, false, id.ends_with("miniboss"))
			stage.add_child(f)
			while not f.choice.active:
				await _frames(1)
			await _frames(20)
			_shot(key + "-fight-" + id)
			f.queue_free()
			await _frames(2)
		var b := BounceScreen.new()
		b.setup(SeededRng.new(11), 1)
		b.world_id = w[1]
		stage.add_child(b)
		while b.phase != "aiming":
			await _frames(1)
		b.aim = 120
		await _frames(20)
		_shot(key + "-boss")
		b.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
