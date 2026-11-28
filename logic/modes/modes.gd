## The modes on the main menu (Phase 6 of the ship plan, 2026-11-28): the
## Arena (fights only, logic/modes/arena_run.gd) and Bounce (beaten bosses
## again). Both open as the child meets them on the path (logic/core/book.gd)
## and pay small, so the path stays the way forward.
##
## A mode that has just opened shows "New!" on its button until it is first
## tapped: save["modes_seen"] = ["arena", ...].
##
## Bounce replays the board of a boss already beaten, at the child's Level.
## A win pays bounce_pay() of the world's currency (BounceScreen's bucket,
## content/bounce/tuning.json "mode_gems") and nothing else: no mark, no
## star, no Level, and the saved run stays as it was.
extends RefCounted

const Book := preload("res://logic/core/book.gd")
const Content := preload("res://logic/core/content.gd")
const Store := preload("res://logic/core/store.gd")
const BounceFight := preload("res://logic/bounce/bounce_fight.gd")

const ARENA := "arena"
const BOUNCE := "bounce"
const SEEN_KEY := "modes_seen"
## The bounce bucket's kind (BounceScreen.set_bonus).
const BOUNCE_BONUS := "mode"


static func is_open(save: Dictionary, mode: String) -> bool:
	match mode:
		ARENA:
			return Book.arena_open(save)
		BOUNCE:
			return Book.bounce_open(save)
	return false


## Open and not tapped yet: the button wears "New!".
static func is_new(save: Dictionary, mode: String) -> bool:
	return is_open(save, mode) and not seen(save).has(mode)


static func seen(save: Dictionary) -> Array:
	var s = save.get(SEEN_KEY, [])
	return s if s is Array else []


## The button was tapped while open: "New!" comes off for good.
static func mark_seen(save: Dictionary, mode: String) -> void:
	var s := seen(save).duplicate()
	if not s.has(mode):
		s.append(mode)
	save[SEEN_KEY] = s


## The bosses Bounce offers: [{world, name}] for each world whose boss has
## been beaten, in map order.
static func bounce_bosses(save: Dictionary) -> Array:
	var names := {}
	for w in Content.worlds():
		names[String(w["id"])] = String(w.get("name", w["id"]))
	var out := []
	for id in Book.bosses_beaten(save):
		out.append({"world": id, "name": names.get(id, id)})
	return out


## The boss fight for a world at the child's Level: {level_id, boss_grade},
## the same grade the path's boss asks there (main.gd _start_boss).
static func bounce_board(world_id: String, level: int, levels := {}) -> Dictionary:
	var lv_all: Dictionary = levels if not levels.is_empty() else Content.levels()
	var id := Content.level_id(world_id, clampi(level, 1, Content.LEVEL_COUNT))
	var lv: Dictionary = lv_all.get(id, {})
	return {"level_id": id, "boss_grade": int(lv.get("boss_grade", 1))}


## What a Bounce win pays: tuning.json "screen" "mode_gems" (the same number
## BounceScreen.set_bonus("mode") pours from the bucket).
static func bounce_pay() -> int:
	return int(BounceFight.load_tuning()["screen"].get("mode_gems", 2))


## A Bounce win banked the way BounceScreen's bucket banks it: n of the
## world's currency, nothing else. Returns the currency.
static func bank_bounce(save: Dictionary, world_id: String, n: int) -> String:
	var cur := Store.currency_of_world(Store.catalog(), world_id)
	Store.add(save, cur, n)
	return cur
