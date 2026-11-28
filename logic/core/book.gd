## The monster book (Phase 6 of the ship plan, 2026-11-28): every monster
## and miniboss beaten gets a card; every boss beaten leaves a trophy on the
## map. Pure data over the save, no nodes.
##
## Save: save["book"] = {monster id: [Level numbers it was beaten at]}, the
## same shape as marks and stars, so SaveData.merge unions it. Bosses are
## not stored here: a boss beaten is the world's mark (save["marks"]).
##
## The modes (Arena, Bounce) open from what the book holds, so the path
## stays the way forward:
##   Arena  opens once ARENA_OPENS_AT monsters have a card;
##   Bounce opens once one boss is beaten (any world, any Level).
extends RefCounted

const Content := preload("res://logic/core/content.gd")
const Monsters := preload("res://logic/fight/monsters.gd")

const KEY := "book"
const ARENA_OPENS_AT := 3


## A monster (or miniboss) beaten at Level n. Returns true the first time
## it gets a card at all (the "new card" moment).
static func record(save: Dictionary, monster_id: String, level: int) -> bool:
	if not Monsters.ROSTER.has(monster_id):
		return false  # nothing fought, or a fighter the book has no page for
	if not save.has(KEY) or not (save[KEY] is Dictionary):
		save[KEY] = {}
	var book: Dictionary = save[KEY]
	var first := not book.has(monster_id)
	if first:
		book[monster_id] = []
	if level > 0 and not book[monster_id].has(level):
		book[monster_id].append(level)
		book[monster_id].sort()
	return first


static func has_card(save: Dictionary, monster_id: String) -> bool:
	return save.get(KEY, {}).has(monster_id)


## Monster ids with a card, in roster order (the book's page order).
static func cards(save: Dictionary) -> Array:
	var out := []
	var book: Dictionary = save.get(KEY, {})
	for id in Monsters.ROSTER:
		if book.has(id):
			out.append(id)
	return out


## Plain monsters with a card (no minibosses, no mimic): who the Arena sends.
static func arena_monsters(save: Dictionary) -> Array:
	var out := []
	for id in cards(save):
		if Monsters.ROSTER[id]["role"] == "monster":
			out.append(id)
	return out


## World ids whose boss has been beaten at any Level, in map order.
static func bosses_beaten(save: Dictionary) -> Array:
	var out := []
	for w in Content.worlds():
		if not save.get("marks", {}).get(String(w["id"]), []).is_empty():
			out.append(String(w["id"]))
	return out


## The world's boss has been beaten at Level n (its trophy on that map).
static func trophy_at(save: Dictionary, world_id: String, level: int) -> bool:
	var ids := Content.level_ids(world_id)
	if level < 1 or level > ids.size():
		return false
	return save.get("marks", {}).get(world_id, []).has(int(ids[level - 1]))


static func arena_open(save: Dictionary) -> bool:
	return arena_monsters(save).size() >= ARENA_OPENS_AT


static func bounce_open(save: Dictionary) -> bool:
	return not bosses_beaten(save).is_empty()
