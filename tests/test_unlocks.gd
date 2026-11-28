## Phase 6 unlocks (2026-11-28): the monster book (record, cards, trophies,
## merge, old saves) and the Level heroes (won by the first full pass of a
## Level, given again to a save loaded after the fact, shown in the store).
extends "res://tests/support/test_case.gd"

const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Store := preload("res://logic/core/store.gd")
const Book := preload("res://logic/core/book.gd")
const SaveStore := preload("res://game/save_store.gd")


func _fresh() -> Dictionary:
	return SaveData.new_profile("t")


## Beats world i at Level n the way the boss does (the mini map step).
func _beat(save: Dictionary, i: int, n: int) -> void:
	var w: Dictionary = Content.worlds()[i]
	AreaFlow.enter(save, Content.area(String(w["area"])), Content.level_id(String(w["id"]), n), AreaFlow.MAP)


func _pass(save: Dictionary, n: int) -> void:
	for i in Content.worlds().size():
		_beat(save, i, n)


# --- the monster book --------------------------------------------------------

func test_book_record_and_cards() -> bool:
	var s := _fresh()
	eq(s["book"], {}, "a new profile has an empty book")
	check(Book.record(s, "craggy", 2), "first win: a new card")
	check(not Book.record(s, "craggy", 1), "again: no new card")
	check(not Book.record(s, "craggy", 2), "the same Level again")
	eq(s["book"]["craggy"], [1, 2], "Levels kept once each, in order")
	check(Book.record(s, "blorp", 1), "Blorp's card")
	check(Book.record(s, "lava_miniboss", 1), "the miniboss's card")
	check(Book.record(s, "mimic", 1), "the mimic gets a card too")
	eq(Book.cards(s), ["blorp", "craggy", "mimic", "lava_miniboss"], "cards in roster order")
	eq(Book.arena_monsters(s), ["blorp", "craggy"], "the Arena sends plain monsters only")
	check(not Book.record(s, "", 1), "no fighter, no card")
	check(not Book.record(s, "nobody", 1), "an unknown fighter has no page")
	check(not s["book"].has("") and not s["book"].has("nobody"), "nothing stored for them")
	return true


func test_trophies_follow_the_boss_marks() -> bool:
	var s := _fresh()
	check(not Book.trophy_at(s, "lava_caves", 1), "no trophy before the boss")
	_beat(s, 0, 1)
	_beat(s, 0, 3)
	check(Book.trophy_at(s, "lava_caves", 1), "Lava 1 trophy")
	check(not Book.trophy_at(s, "lava_caves", 2), "not Lava 2")
	check(Book.trophy_at(s, "lava_caves", 3), "Lava 3 trophy")
	check(not Book.trophy_at(s, "crystal_mines", 1), "not Crystal 1")
	check(not Book.trophy_at(s, "lava_caves", 0) and not Book.trophy_at(s, "lava_caves", 7), "no Level 0 or 7")
	eq(Book.bosses_beaten(s), ["lava_caves"], "one boss beaten")
	return true


func test_book_survives_saves_and_merges() -> bool:
	var s := _fresh()
	Book.record(s, "knocker", 1)
	var back := SaveData.from_text(SaveData.to_text(s), "t")
	eq(back["book"], {"knocker": [1]}, "book round trip")
	var old := SaveData.from_text('{"version": 2, "gems": 3, "marks": {}}', "t")
	eq(old["book"], {}, "a save from before the book loads with an empty one")
	var broken := SaveData.from_text('{"version": 2, "book": [1, 2]}', "t")
	eq(broken["book"], {}, "a broken book resets")
	# two tablets: each beat different fighters; nothing is lost
	var a := _fresh()
	Book.record(a, "blorp", 1)
	Book.record(a, "craggy", 2)
	var b := _fresh()
	Book.record(b, "blorp", 3)
	Book.record(b, "nixie", 1)
	var snaps := [SaveData.snapshot(a, "d_a", 1, 100), SaveData.snapshot(b, "d_b", 1, 200)]
	var m := SaveData.merge(snaps, "t")
	eq(m["book"], {"blorp": [1, 3], "craggy": [2], "nixie": [1]}, "books unioned")
	return true


# --- the Level heroes ----------------------------------------------------------

func test_catalog_level_rewards() -> bool:
	var cat := Store.catalog()
	var ids := []
	for it in Store.reward_items(cat):
		ids.append(it["id"])
		check(not it.has("price"), "%s has no price" % it["id"])
	eq(ids, ["lion", "templar", "phoenix", "bolt_black", "bolt_purple", "bolt_pink"], "one hero per Level 1 to 6")
	for n in range(1, 7):
		eq(Store.reward_level(Store.reward_items(cat)[n - 1]), n, "Level %d" % n)
	for cid in cat["currencies"]:
		check(Store.is_open(cat, cid), "every currency can be earned (%s)" % cid)
		check(not str(cid).ends_with("_stars"), "the star currencies are gone (%s)" % cid)
	for it in cat["items"]:
		if it.has("price"):
			check(cat["currencies"].has(it["price"]["currency"]), "%s priced in a real currency" % it["id"])
	check(not Store.shop_items(cat, "hero").has(Store.item(cat, "lion")), "Leo isn't on the hero tab")
	eq(Store.default_id(cat, "hero"), "robodragon", "Bolt is still the starting hero")
	return true


func test_store_states_of_a_level_hero() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	s["gems"] = 999
	eq(Store.state(cat, s, "lion"), Store.LEVEL, "not won yet: Level 1")
	check(not Store.owns(cat, s, "lion"), "not owned")
	check(Store.is_locked(cat, s, "lion"), "locked")
	check(not Store.can_afford(cat, s, "lion"), "no price to pay")
	check(not Store.buy(cat, s, "lion"), "can't be bought")
	check(not Store.equip(cat, s, "lion"), "can't be put on")
	eq(s["gems"], 999, "nothing spent")
	s["hero"] = "lion"
	eq(Store.equipped(cat, s, "hero"), "robodragon", "a save naming it falls back to Bolt")
	_pass(s, 1)
	Store.grant_level_rewards(cat, s, Content.worlds())
	eq(Store.state(cat, s, "lion"), Store.EQUIPPED, "won: and the save already named it")
	check(Store.equip(cat, s, "robodragon"), "back to Bolt")
	eq(Store.state(cat, s, "lion"), Store.OWNED, "won: Use")
	check(Store.equip(cat, s, "lion"), "put Leo on")
	eq(Store.equipped(cat, s, "hero"), "lion", "Leo in use")
	eq(Store.state(cat, s, "templar"), Store.LEVEL, "Sir Tam still waits for Level 2")
	return true


func test_first_full_pass_wins_its_hero_once() -> bool:
	var cat := Store.catalog()
	var worlds := Content.worlds()
	var s := _fresh()
	eq(Store.grant_level_rewards(cat, s, worlds), [], "nothing at the start")
	for i in worlds.size() - 1:
		_beat(s, i, 1)
		eq(Store.grant_level_rewards(cat, s, worlds), [], "not before the last world (%d)" % i)
	_beat(s, worlds.size() - 1, 1)
	eq(Store.grant_level_rewards(cat, s, worlds), ["lion"], "Space 1 finishes the pass: Leo")
	eq(s["owned"], ["lion"], "owned")
	eq(Store.grant_level_rewards(cat, s, worlds), [], "a replay gives nothing more")
	_beat(s, 0, 1)
	eq(Store.grant_level_rewards(cat, s, worlds), [], "beating Lava 1 again gives nothing")
	eq(s["owned"], ["lion"], "still once")
	# Level 2 in a different order still needs all five
	for i in [0, 1, 2, 3]:
		_beat(s, i, 2)
	eq(Store.grant_level_rewards(cat, s, worlds), [], "four of five at Level 2")
	_beat(s, 4, 2)
	eq(Store.grant_level_rewards(cat, s, worlds), ["templar"], "Level 2: Sir Tam")
	return true


## Only play wins a hero: a grown-up's Level pick or Debug's "Map: all open"
## opens Levels but gives nothing.
func test_only_play_wins_heroes() -> bool:
	var cat := Store.catalog()
	var worlds := Content.worlds()
	var s := _fresh()
	AreaFlow.pick_level(s, 6)
	s["debug_unlock"] = true
	eq(Store.grant_level_rewards(cat, s, worlds), [], "a pick and Debug give nothing")
	_pass(s, 4)
	eq(Store.grant_level_rewards(cat, s, worlds), ["bolt_black"], "a full pass of Level 4: Black Bolt only")
	return true


## A save that beat Levels before the heroes came in gets them on load,
## all of them at once, in Level order.
func test_heroes_given_to_old_saves_on_load() -> bool:
	var s := _fresh()
	_pass(s, 1)
	_pass(s, 2)
	_pass(s, 3)
	_beat(s, 0, 4)
	var was_dir := SaveStore.dir
	var d := "user://test_unlocks_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(d)
	SaveStore.dir = d
	SaveStore.write_to(SaveStore.path_for("t"), SaveData.to_text(s))
	var loaded := SaveStore.read_profile("t")
	SaveStore.dir = was_dir
	DirAccess.remove_absolute(d.path_join("profile_t.json"))
	DirAccess.remove_absolute(d)
	eq(loaded["owned"], ["lion", "templar", "phoenix"], "Levels 1 to 3 beaten: three heroes")
	eq(Store.state(Store.catalog(), loaded, "bolt_black"), Store.LEVEL, "Level 4 not finished")
	var fresh := SaveData.from_text("", "t")
	eq(Store.grant_level_rewards(Store.catalog(), fresh, Content.worlds()), [], "a new save gets none")
	return true
