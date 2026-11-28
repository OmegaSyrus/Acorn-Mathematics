## The modes' screen flow (Phase 6, 2026-11-28), kept out of main.gd: the
## main menu's Arena and Bounce buttons call arena() and bounce(); main is
## the host (its stage, game menu, save, Level and seed).
##
## Arena: the between-fights screen, then each fight (FightScreen) with the
## hearts carried on; a loss shows Try (the round again from fight 1) and
## Back. Bounce: the picker, then the boss's board (BounceScreen) at the
## child's Level, paying the small mode bucket; a loss offers Try or Back.
## Neither one touches marks, stars, the Level or the saved run.
extends RefCounted

const Content := preload("res://logic/core/content.gd")
const Book := preload("res://logic/core/book.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ArenaRun := preload("res://logic/modes/arena_run.gd")
const Modes := preload("res://logic/modes/modes.gd")
const SaveStore := preload("res://game/save_store.gd")
const PlayLog := preload("res://game/play_log.gd")
const ArenaScreen := preload("res://game/arena_screen.gd")
const BouncePickerScreen := preload("res://game/bounce_picker_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")

var host  # main.gd


func _init(main_node) -> void:
	host = main_node


## The Arena from the main menu: a new round at the menu's Level.
func arena() -> void:
	SaveStore.write(host.save)  # "New!" came off the button
	var run := ArenaRun.new(Book.arena_monsters(host.save), host.play_grade, host._new_seed(),
			ScrollRun.fights_setting(host.save))
	if run.monsters.is_empty():
		host.show_map()
		return
	_log_arena(run)
	PlayLog.event("arena_start", {"monsters": run.monsters.duplicate(), "try": run.tries})
	_arena_screen(run, 0)


## Between fights (and after the last one, or a loss).
func _arena_screen(run: ArenaRun, paid: int) -> void:
	var a := ArenaScreen.new()
	a.setup(run, paid)
	a.go.connect(func():
		if run.phase == ArenaRun.WON:
			arena.call_deferred()
		elif run.phase == ArenaRun.LOST:
			run.restart()
			_log_arena(run)
			PlayLog.event("arena_start", {"monsters": run.monsters.duplicate(), "try": run.tries})
			_arena_fight.call_deferred(run)
		else:
			_arena_fight.call_deferred(run))
	a.back.connect(func(): host.show_map.call_deferred())
	host._swap(a)
	host.menu.visible = false
	Music.play_menu()


## One fight of the round: the math the path asks for this monster at the
## Level, the hearts brought from the fight before.
func _arena_fight(run: ArenaRun) -> void:
	var fg := run.fight_now()
	var mon := run.monster_now()
	_log_arena(run)
	Music.play_world(ArenaRun.world_of(mon))
	host.menu.visible = true
	var f := FightScreen.new()
	f.setup(SeededRng.new(run.fight_seed()), int(fg["grade"]), mon, false, false, host.debug_on, run.hearts)
	f.fight.set_top(int(fg["top"]))
	f.done.connect(func(won: bool):
		var out := run.resolve(won, f.fight.hero_hearts)
		var paid := 0
		if out == ArenaRun.WON:
			paid = run.reward(host.save)
			SaveStore.write(host.save)
			PlayLog.event("arena_win", {"gems": paid, "hearts_left": run.hearts, "try": run.tries})
		elif out == ArenaRun.LOST:
			PlayLog.event("arena_lost", {"fight": run.at + 1, "monster": mon, "try": run.tries})
		_arena_screen.call_deferred(run, paid))
	host._swap.call_deferred(f)


## The play log's place for the Arena: area "arena", the world and level of
## the fight up next.
func _log_arena(run: ArenaRun) -> void:
	var mon := run.monster_now()
	var world := ArenaRun.world_of(mon) if mon != "" else ""
	PlayLog.set_place({"world": world, "id": "arena"}, run.level_id_now(), run.level)
	PlayLog.place["fights"] = ScrollRun.fights_setting(host.save)


## Bounce from the main menu: the picker of beaten bosses.
func bounce() -> void:
	SaveStore.write(host.save)
	var p := BouncePickerScreen.new()
	p.setup(host.save)
	if p.bosses.is_empty():
		p.free()
		host.show_map()
		return
	p.picked.connect(func(world_id: String): bounce_boss.call_deferred(world_id))
	p.back.connect(func(): host.show_map.call_deferred())
	host._swap(p)
	host.menu.visible = false
	Music.play_menu()


## One beaten boss again, at the menu's Level. A win pays the mode's small
## bucket (BounceScreen banks it) and goes back to the picker; on a loss Try
## plays it again and Back goes to the picker.
func bounce_boss(world_id: String) -> void:
	var board := Modes.bounce_board(world_id, host.play_grade, host.levels)
	PlayLog.set_place({"world": world_id, "id": "bounce"}, int(board["level_id"]), host.play_grade)
	PlayLog.place["fights"] = ScrollRun.fights_setting(host.save)
	PlayLog.event("bounce_start")
	Music.play_world(world_id)
	host.menu.visible = true
	var b := BounceScreen.new()
	b.world_id = world_id
	b.setup(SeededRng.new(host._new_seed()), int(board["boss_grade"]), host.debug_on)
	b.save = host.save
	b.set_bonus(Modes.BOUNCE_BONUS)
	b.back_label = "Back"
	b.done.connect(func(won: bool):
		if won or b.to_map:
			bounce.call_deferred()
		else:
			bounce_boss.call_deferred(world_id))
	host._swap.call_deferred(b)
