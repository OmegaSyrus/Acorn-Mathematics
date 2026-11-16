## Probe: a real wrong pick on the crossing and in a fight; logs what Ellwynn plays.
##   godot --headless --path . res://tools/voice_check/answer_probe.tscn
extends Node2D

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")


func _ready() -> void:
	InputSetup.register()
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 2)
	var s := ScrollScreen.new()
	s.setup(run, {"gems": 6}, false)
	add_child(s)
	await get_tree().create_timer(0.5).timeout
	s.rolled.emit()
	while not s.choice.active:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var p: Dictionary = s.run.problem
	var wrong: int = (int(p["answer_index"]) + 1) % p["choices"].size()
	print("answer=", p["answer"], " wrong pick=", wrong)
	var t0 := Time.get_ticks_msec()
	s.choice.picked.emit(wrong)
	var seen := false
	for i in 60:
		await get_tree().create_timer(0.1).timeout
		if Ellwynn._cur_file.contains("answer") and not seen:
			seen = true
			print("answer line started at %.2f s: %s playing=%s mode=%s" % [(Time.get_ticks_msec() - t0) / 1000.0, Ellwynn._cur_file, Ellwynn.player.playing, Ellwynn.mode])
		if seen:
			print("  %.1f playing=%s pos=%.2f vol=%.1f bus_mute=%s" % [(Time.get_ticks_msec() - t0) / 1000.0, Ellwynn.player.playing, Ellwynn.player.get_playback_position(), Ellwynn.player.volume_db, AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice"))])
	print("crossing seen=", seen, " last file=", Ellwynn._cur_file)
	s.queue_free()
	Ellwynn.stop_voice()
	for grade in [1, 2]:
		var f := FightScreen.new()
		f.setup(SeededRng.new(78), grade, "blorp", false, false)
		add_child(f)
		while not f.choice.active:
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		var atk = f.fight.attack
		var t1 := Time.get_ticks_msec()
		Ellwynn._cur_file = ""
		f.choice.picked.emit((atk.answer_index + 1) % atk.choices.size())
		var got := ""
		for i in 40:
			await get_tree().create_timer(0.05).timeout
			if Ellwynn.player.playing and got == "":
				got = "%s at %.2f s" % [Ellwynn._cur_file, (Time.get_ticks_msec() - t1) / 1000.0]
		print("fight grade ", grade, " answer=", atk.answer, " -> ", got if got != "" else "NOTHING PLAYED")
		f.queue_free()
		Ellwynn.stop_voice()
	get_tree().quit()
