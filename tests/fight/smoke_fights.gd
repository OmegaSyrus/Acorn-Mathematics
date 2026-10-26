## Plays the real area screen with fights headless, as a scene so autoloads
## run. Not a unit test: it checks the fight screen and its wiring play
## through without script errors.
##   godot --headless --path . res://tests/fight/smoke_fights.tscn [-- --grade=2]
## Plan: lose the first fight on purpose (area restarts), answer the mimic's
## lock wrong once, then play perfectly to the end. Exit 0 when the area
## clears with the expected events.
extends Node

const Content := preload("res://logic/core/content.gd")
const InputSetup := preload("res://game/input_setup.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const SaveStore := preload("res://game/save_store.gd")
const AreaRun := preload("res://logic/path/area_run.gd")
const AreaScreen := preload("res://game/area_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")

const TIMEOUT_MS := 240000

var run: AreaRun
var area: AreaScreen
var lost_first_fight := false
var fumbled_mimic_lock := false
var fight_picks := 0
var fights_seen := {}
var _start_ms := 0
## The area screen saves after every task to the real profile file, so the
## smoke run puts back whatever save was there before.
var _saved_before = null


func _ready() -> void:
	if FileAccess.file_exists(SaveStore.path()):
		_saved_before = FileAccess.get_file_as_string(SaveStore.path())
	InputSetup.register()
	Engine.time_scale = 8.0
	_start_ms = Time.get_ticks_msec()
	var grade_id := 2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grade="):
			grade_id = int(arg.trim_prefix("--grade="))
	var grades := Content.grades()
	run = AreaRun.new(Content.area("lava_1_fights"), grades[grade_id], Content.stickers(), 1234)
	area = AreaScreen.new()
	area.setup(run, SaveData.new_profile(SaveStore.PROFILE), false)
	area.finished.connect(_on_finished)
	add_child(area)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _start_ms > TIMEOUT_MS:
		_fail("timed out at task %d phase %s" % [run.task_index, run.phase])
		return
	var now := Time.get_ticks_msec()
	if area.tray_waiting and area.tray_gate.accepts(now):
		area.rolled.emit()
	var fs: FightScreen = null
	for c in area.get_children():
		if c is FightScreen:
			fs = c
	if fs != null:
		if fs.choice.active and fs.choice.gate.is_open(now):
			fights_seen[fs.fight.monster_id] = true
			var atk = fs.fight.attack
			var pick: int = atk.answer_index
			if not lost_first_fight and fs.fight.monster_id == "blorp":
				pick = (pick + 1) % 4
				if fs.fight.hero_hearts == 1:
					lost_first_fight = true
			fight_picks += 1
			fs.choice._pick(pick)
		return
	if area.choice.active and area.choice.gate.is_open(now):
		var pick := 0
		if run.phase == AreaRun.AWAIT_CHOICE:
			pick = run.problem["answer_index"]
			if run.current_task().get("mimic", false) and not fumbled_mimic_lock:
				fumbled_mimic_lock = true
				pick = (pick + 1) % run.problem["choices"].size()
		area.choice._pick(pick)


func _on_finished() -> void:
	var results := []
	for e in run.events:
		results.append(e["result"])
	print("events: ", results)
	print("fight picks: %d, monsters seen: %s, attempts: %d" % [fight_picks, str(fights_seen.keys()), run.attempt])
	var want := ["fight_lost", "fight_won", "mimic"]
	for w in want:
		if not results.has(w):
			_fail("no %s event" % w)
			return
	if not (fights_seen.has("blorp") and fights_seen.has("mimic") and fights_seen.has("craggy")):
		_fail("did not fight every monster")
		return
	if run.phase != AreaRun.CLEARED or run.attempt != 2:
		_fail("expected a clear on attempt 2, got phase %s attempt %d" % [run.phase, run.attempt])
		return
	print("SMOKE OK")
	_quit(0)


func _fail(msg: String) -> void:
	print("SMOKE FAIL: ", msg)
	_quit(1)


func _quit(code: int) -> void:
	if _saved_before == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path()))
	else:
		var f := FileAccess.open(SaveStore.path(), FileAccess.WRITE)
		f.store_string(_saved_before)
		f.close()
	set_process(false)
	get_tree().quit(code)
