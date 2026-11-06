## The store: catalog checks, buy / equip / can-afford, and old saves.
extends "res://tests/support/test_case.gd"

const Store := preload("res://logic/core/store.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")


func _fresh() -> Dictionary:
	return SaveData.new_profile("1")


func test_catalog_is_well_formed() -> bool:
	var cat := Store.catalog()
	var ids := {}
	for it in cat["items"]:
		for key in ["id", "kind", "name"]:
			check(it.has(key), "item missing %s: %s" % [key, it])
		check(not ids.has(it["id"]), "duplicate id " + str(it["id"]))
		ids[it["id"]] = true
		check(Store.KINDS.has(it["kind"]), "bad kind " + str(it["kind"]))
		check(str(it["name"]).length() <= 10, "short name for %s" % it["id"])
		if it.has("price"):
			var p: Dictionary = it["price"]
			check(cat["currencies"].has(p["currency"]), "%s: unknown currency %s" % [it["id"], p["currency"]])
			check(int(p["amount"]) > 0, "%s: price above 0" % it["id"])
		if it["kind"] == "hero" or it["kind"] == "color":
			var tex = load(it["art"])
			check(tex is Texture2D, "%s: art %s" % [it["id"], it["art"]])
			if tex is Texture2D:
				var h: float = tex.get_height() * float(it.get("scale", 1.0))
				check(h >= 100.0 and h <= 125.0, "%s: drawn %d px tall, near the dragon's 115" % [it["id"], h])
		else:
			for key in ["style", "face", "shade", "pip"]:
				check(it.get("look", {}).has(key), "%s: look.%s" % [it["id"], key])
	for kind in Store.KINDS:
		check(Store.default_id(cat, kind) != "", "a free %s to start with" % kind)
	for cid in cat["currencies"]:
		var c: Dictionary = cat["currencies"][cid]
		check(c.has("icon") and c["icon"].has("shape"), "currency %s has an icon" % cid)
	eq(Store.default_id(cat, "hero"), "robodragon", "the robot dragon is the starting hero")
	eq(Store.default_id(cat, "dice"), "classic", "the white dice are the starting dice")
	eq(Store.default_id(cat, "color"), "steel", "the dragon starts steel")
	# Terrence 2026-11-06: dragon colours red, black, green, purple, pink
	var colors := []
	for it in Store.items(cat, "color"):
		colors.append(it["id"])
	eq(colors, ["steel", "red", "black", "green", "purple", "pink"], "dragon colours")
	eq(Store.items(cat, "dice").size(), 1, "dice skins are gone from the store")
	check(cat["currencies"].has("broaches"), "the Bog pays in broaches")
	return true


## Terrence 2026-11-05: for now only the helmet slime can be bought, with gems.
func test_only_the_slime_is_buyable_now() -> bool:
	var cat := Store.catalog()
	var open_priced := []
	for it in cat["items"]:
		if it.has("price") and Store.is_open(cat, it["price"]["currency"]):
			open_priced.append(it["id"])
	eq(open_priced, ["slime_knight"], "open-currency items")
	eq(Store.item(cat, "slime_knight")["price"], {"currency": "gems", "amount": 40}, "slime price")
	return true


## The slime takes about three cleared Acorn crossings: more than two runs can
## give (bar all-4 chests), no more than three average runs.
func test_slime_price_is_about_three_runs() -> bool:
	var area := Content.area("lava_scroll")
	var chests := 0
	for s in area["spaces"]:
		if s["type"] == "chest":
			chests += 1
	var lo: int = area["chest_gems"][0]
	var hi: int = area["chest_gems"][1]
	var mean_run := chests * (lo + hi) / 2.0
	var price: int = Store.item(Store.catalog(), "slime_knight")["price"]["amount"]
	check(price >= 2 * chests * hi, "two runs can't buy it (max %d)" % (2 * chests * hi))
	check(price <= 3 * mean_run, "three average runs can (%d)" % (3 * mean_run))
	# measured: a perfect run banks exactly its chests' gems
	var total := 0
	var n := 400
	for seed_value in n:
		var run := ScrollRun.new(area, Content.grades()[1], seed_value + 1)
		while run.phase != ScrollRun.CLEARED:
			if run.phase == ScrollRun.AWAIT_FIGHT:
				run.resolve_fight(true)
				continue
			var p := run.roll()
			run.choose(p["answer_index"])
		total += run.gems
	var measured := float(total) / n
	check(absf(measured - mean_run) < 0.6, "mean gems per run %.2f, expected %.1f" % [measured, mean_run])
	return true


func test_fresh_profile_owns_and_uses_the_defaults() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	check(Store.owns(cat, s, "robodragon"), "owns the dragon")
	check(Store.owns(cat, s, "classic"), "owns the white dice")
	check(not Store.owns(cat, s, "slime_knight"), "not the slime")
	eq(Store.equipped(cat, s, "hero"), "robodragon", "hero")
	eq(Store.equipped(cat, s, "dice"), "classic", "dice")
	eq(Store.state(cat, s, "robodragon"), Store.EQUIPPED, "dragon state")
	eq(Store.state(cat, s, "slime_knight"), Store.SHORT, "slime with no gems")
	eq(Store.state(cat, s, "lion"), Store.LOCKED, "lion")
	eq(Store.equipped(cat, s, "color"), "steel", "colour")
	eq(Store.state(cat, s, "red"), Store.LOCKED, "red dragon")
	return true


func test_buy_the_slime() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	s["gems"] = 39
	check(not Store.can_afford(cat, s, "slime_knight"), "39 is not enough")
	check(not Store.buy(cat, s, "slime_knight"), "can't buy at 39")
	eq(s["gems"], 39, "no gems taken")
	SaveData.add_gems(s, 4)
	eq(Store.state(cat, s, "slime_knight"), Store.BUY, "buyable at 43")
	check(Store.buy(cat, s, "slime_knight"), "bought")
	eq(s["gems"], 3, "40 spent")
	eq(s["owned"], ["slime_knight"], "owned list")
	eq(Store.state(cat, s, "slime_knight"), Store.OWNED, "owned, not in use yet")
	check(not Store.buy(cat, s, "slime_knight"), "can't buy twice")
	eq(s["gems"], 3, "nothing spent twice")
	check(Store.equip(cat, s, "slime_knight"), "equip")
	eq(Store.equipped(cat, s, "hero"), "slime_knight", "slime in use")
	eq(Store.state(cat, s, "robodragon"), Store.OWNED, "dragon can be used again")
	check(Store.equip(cat, s, "robodragon"), "back to the dragon")
	eq(s["hero"], "robodragon", "saved")
	return true


func test_reset_gems_keeps_what_was_bought() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	s["gems"] = 52
	check(Store.buy(cat, s, "slime_knight"), "bought")
	Store.equip(cat, s, "slime_knight")
	Store.reset_balance(s, "gems")
	eq(s["gems"], 0, "gems back to zero")
	eq(s["owned"], ["slime_knight"], "slime still owned")
	eq(Store.equipped(cat, s, "hero"), "slime_knight", "slime still in use")
	Store.reset_balance(s, "gems")
	eq(s["gems"], 0, "reset at zero stays zero")
	var back := SaveData.from_text(SaveData.to_text(s), "1")
	eq(back["gems"], 0, "save round trip")
	eq(back["owned"], ["slime_knight"], "owned survives the round trip")
	return true


func test_locked_items_cant_be_bought_or_used() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	Store.add(s, "crystals", 999)
	eq(Store.balance(s, "crystals"), 999, "crystals kept in currencies")
	eq(s["gems"], 0, "gems untouched")
	check(Store.is_locked(cat, s, "red"), "crystals can't be earned yet")
	check(not Store.buy(cat, s, "red"), "locked: no buy")
	check(not Store.equip(cat, s, "red"), "not owned: no equip")
	check(not Store.equip(cat, s, "nonsense"), "unknown id")
	eq(Store.balance(s, "crystals"), 999, "nothing spent")
	return true


## A later area opens its currency in the data alone, with no code change.
func test_opening_a_currency_in_data_unlocks_its_items() -> bool:
	var cat: Dictionary = Store.catalog().duplicate(true)
	cat["currencies"]["crystals"]["open"] = true
	var s := _fresh()
	eq(Store.state(cat, s, "red"), Store.SHORT, "open but no crystals")
	Store.add(s, "crystals", 25)
	check(Store.buy(cat, s, "red"), "bought the red dragon")
	eq(Store.balance(s, "crystals"), 5, "20 spent")
	check(Store.equip(cat, s, "red"), "equip the colour")
	eq(Store.equipped(cat, s, "color"), "red", "red in use")
	eq(Store.equipped(cat, s, "hero"), "robodragon", "hero unchanged")
	return true


func test_equipped_falls_back_when_the_save_is_odd() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	s["hero"] = "slime_knight"  # not owned
	s["dice"] = "robodragon"     # wrong kind
	eq(Store.equipped(cat, s, "hero"), "robodragon", "unowned hero")
	eq(Store.equipped(cat, s, "dice"), "classic", "wrong kind")
	return true


func test_old_saves_load_with_store_defaults() -> bool:
	var old := '{"version": 1, "profile": "1", "stickers": ["ember"], "gems": 17, "marks": {"lava_scroll": [1]}, "run": null}'
	var s := SaveData.from_text(old, "1")
	eq(s["gems"], 17, "gems kept")
	eq(s["stickers"], ["ember"], "stickers kept")
	eq(s["owned"], [], "nothing bought")
	eq(s["currencies"], {}, "no other currencies")
	eq(s["hero"], "robodragon", "hero default")
	eq(s["dice"], "classic", "dice default")
	eq(s["color"], "steel", "colour default")
	var broken := SaveData.from_text('{"gems": 5, "owned": "oops", "currencies": 3}', "1")
	eq(broken["owned"], [], "a broken owned list resets")
	eq(broken["currencies"], {}, "a broken currencies dict resets")
	eq(broken["gems"], 5, "gems kept")
	var s2 := _fresh()
	s2["gems"] = 50
	Store.buy(Store.catalog(), s2, "slime_knight")
	Store.equip(Store.catalog(), s2, "slime_knight")
	var back := SaveData.from_text(SaveData.to_text(s2), "1")
	eq(back["owned"], ["slime_knight"], "owned round trip")
	eq(back["hero"], "slime_knight", "hero round trip")
	eq(back["gems"], 10, "gems round trip")
	return true


## Every dice skin has six 96 px faces, and the take-away die stays red in
## every skin while no add die looks red (red = subtract).
func test_dice_skins_keep_the_red_die_red() -> bool:
	var DiceSkins = load("res://game/ui/dice_skins.gd")
	for it in Store.items(Store.catalog(), "dice"):
		for v in range(1, 7):
			for slip in [false, true]:
				var tex: Texture2D = DiceSkins.face(it["id"], v, slip)
				check(tex != null and tex.get_size() == Vector2(96, 96), "%s %d is a 96 px face" % [it["id"], v])
		var add_col: Color = DiceSkins.face(it["id"], 5, false).get_image().get_pixel(48, 14)
		var sub_col: Color = DiceSkins.face(it["id"], 5, true).get_image().get_pixel(48, 14)
		check(sub_col.r - maxf(sub_col.g, sub_col.b) > 0.25, "%s: the take-away die is red (%s)" % [it["id"], sub_col])
		check(add_col.r - maxf(add_col.g, add_col.b) < 0.2, "%s: the add die is not red (%s)" % [it["id"], add_col])
	return true
