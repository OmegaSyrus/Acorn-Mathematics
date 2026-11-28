## The Arena (Phase 6 of the ship plan, 2026-11-28): fights only. A round is
## ROUND_FIGHTS monsters from the book, one after another, at the child's
## Level. Each fight asks the math the path asks for that monster in its
## world at that Level (ScrollRun.monster_fight, with the Debug fight
## switch). The hero starts with HERO_HEARTS and carries them from fight to
## fight like the crossing, with no heart stones and no refills.
##
## No gentle failing: a lost fight ends the round and the child starts it
## over from fight 1 (the same monsters, new dice), nothing paid. Clearing
## every fight pays REWARD_GEMS once. Small on purpose: the big bonuses stay
## on the path.
##
## Pure logic, no nodes: the game asks monster_now() and fight_now(), plays
## the fight, and reports it with resolve().
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const Book := preload("res://logic/core/book.gd")
const Store := preload("res://logic/core/store.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")

const ROUND_FIGHTS := 5
const HERO_HEARTS := 3
const REWARD_GEMS := 3

const READY := "ready"   # the next fight waits for Go
const WON := "won"       # every fight won
const LOST := "lost"     # a fight lost: Try starts the round over

var level := 1
var fight_math := ScrollRun.FIGHTS_STEP_BEFORE
var rng: Rng
var monsters := []       # the round's monster ids, in fight order
var at := 0              # the fight up next (0 = the first)
var hearts := HERO_HEARTS
var phase := READY
var tries := 1           # 1 for the first go at this round, +1 per restart
var paid := false

static var _levels := {}
static var _area_of_world := {}
static var _world_of := {}


## pool: the monsters the book holds (Book.arena_monsters); level: the
## child's Level, 1 to 6; math: ScrollRun.fights_setting(save).
func _init(pool: Array, p_level: int, seed_value: int, math := ScrollRun.FIGHTS_STEP_BEFORE) -> void:
	level = clampi(p_level, 1, Content.LEVEL_COUNT)
	fight_math = math
	rng = Rng.new(seed_value)
	monsters = draw_round(playable(pool), rng)


## Opens once the book holds Book.ARENA_OPENS_AT monsters.
static func is_open(save: Dictionary) -> bool:
	return Book.arena_open(save)


## The book's monsters the path still meets (a monster no area holds any
## more has no world to take its math from).
static func playable(pool: Array) -> Array:
	var out := []
	for id in pool:
		if world_of(String(id)) != "":
			out.append(String(id))
	return out


## ROUND_FIGHTS monsters drawn from the pool: each one once before any
## comes back, and never the same one twice in a row.
static func draw_round(pool: Array, r: Rng) -> Array:
	var out := []
	if pool.is_empty():
		return out
	var bag := []
	while out.size() < ROUND_FIGHTS:
		if bag.is_empty():
			bag = pool.duplicate()
			r.shuffle(bag)
			if pool.size() > 1 and not out.is_empty() and bag[bag.size() - 1] == out[out.size() - 1]:
				bag.push_front(bag.pop_back())
		out.append(bag.pop_back())
	return out


## The world whose crossing holds this monster, or "" for none.
static func world_of(monster_id: String) -> String:
	if _world_of.is_empty():
		for w in Content.worlds():
			if not w.has("area"):
				continue
			var area := Content.area(String(w["area"]))
			_area_of_world[String(w["id"])] = area
			for st in area.get("steps", []):
				if str(st.get("type", "")) == "monster" and not _world_of.has(str(st["monster"])):
					_world_of[str(st["monster"])] = String(w["id"])
	return String(_world_of.get(monster_id, ""))


## The level a monster's fight comes from: its world at this Level.
static func level_of(monster_id: String, p_level: int) -> Dictionary:
	if _levels.is_empty():
		_levels = Content.levels()
	return _levels.get(Content.level_id(world_of(monster_id), p_level), {})


## {grade, top}: what this monster asks at this Level, the same as the path.
static func fight_for(monster_id: String, p_level: int, math: String) -> Dictionary:
	world_of(monster_id)
	var area: Dictionary = _area_of_world.get(world_of(monster_id), {})
	return ScrollRun.monster_fight(area, level_of(monster_id, p_level), monster_id, math)


func monster_now() -> String:
	return String(monsters[at]) if at < monsters.size() else ""


func fight_now() -> Dictionary:
	return fight_for(monster_now(), level, fight_math)


## The level id of the fight up next (for the play log).
func level_id_now() -> int:
	return int(level_of(monster_now(), level).get("id", 0))


## A fresh seed for the next fight's dice, from the round's own rng.
func fight_seed() -> int:
	return rng.next_u32()


## The fight up next is over. won: the hero won it; hearts_left: the hero's
## hearts at its end. Returns "next" (on to the next fight), "won" (the
## round is cleared) or "lost" (the round is over; restart() goes again).
func resolve(won: bool, hearts_left: int) -> String:
	assert(phase == READY)
	if not won:
		phase = LOST
		hearts = 0
		return LOST
	hearts = clampi(hearts_left, 1, HERO_HEARTS)
	at += 1
	if at >= monsters.size():
		phase = WON
		return WON
	return "next"


## Try again after a loss: fight 1 again with 3 hearts, the same monsters.
func restart() -> void:
	at = 0
	hearts = HERO_HEARTS
	phase = READY
	tries += 1


## Pays the round's gems into the save, once, after it is cleared. Returns
## what was paid (0 when not cleared, or already paid).
func reward(save: Dictionary) -> int:
	if phase != WON or paid:
		return 0
	paid = true
	Store.add(save, "gems", REWARD_GEMS)
	return REWARD_GEMS
