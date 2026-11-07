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
		if it["kind"] == "hero":
			var tex = load(it["art"])
			check(tex is Texture2D, "%s: art %s" % [it["id"], it["art"]])
			if tex is Texture2D:
				# one pixel grid for every character: no per-hero scale, the art is the size
				check(not it.has("scale"), "%s: heroes are never scaled (Look.CHAR_PX)" % it["id"])
				var h: float = tex.get_height()
				check(h >= 100.0 and h <= 125.0, "%s: %d px tall, near the dragon's 115" % [it["id"], h])
		else:
			for key in ["style", "face", "shade", "pip"]:
				check(it.get("look", {}).has(key), "%s: look.%s" % [it["id"], key])
	for kind in Store.KINDS:
		check(Store.default_id(cat, kind) != "", "a free %s to start with" % kind)
		# the store shows 7 by 2 cards a tab (game/store_screen.gd COLS)
		check(Store.items(cat, kind).size() <= 14, "%s tab fits the 7 by 2 grid (%d)" % [kind, Store.items(cat, kind).size()])
	for cid in cat["currencies"]:
		var c: Dictionary = cat["currencies"][cid]
		check(c.has("icon") and c["icon"].has("shape"), "currency %s has an icon" % cid)
	eq(Store.default_id(cat, "hero"), "robodragon", "the robot dragon is the starting hero")
	eq(Store.default_id(cat, "dice"), "classic", "the white dice are the starting dice")
	return true


## Terrence 2026-11-06: gems buy three Lava items: Red Bolt, Green Bolt and
## the helmet slime (two more Lava items, so gems have more to buy).
func test_gem_items_are_the_lava_items() -> bool:
	var cat := Store.catalog()
	var open_priced := []
	for it in cat["items"]:
		if it.has("price") and Store.is_open(cat, it["price"]["currency"]):
			open_priced.append(it["id"])
	eq(open_priced, ["bolt_red", "bolt_green", "slime_knight"], "open-currency items")
	eq(Store.item(cat, "slime_knight")["price"], {"currency": "gems", "amount": 25}, "slime price")
	return true


## Chests give 1 gem, 2 one time in 6 (Terrence 2026-11-06: "normally 1, rare
## 2"), so a cleared crossing banks about 6. Each gem item takes 2 to 5
## average crossings, and the measured gems per perfect run match the mean.
func test_gem_prices_fit_the_treasure() -> bool:
	var area := Content.area("lava_scroll")
	var chests := 0
	for s in area["spaces"]:
		if s["type"] == "chest":
			chests += 1
	var cfg = area["chest_gems"]
	eq(ScrollRun.chest_range(cfg), [1, 2], "a chest gives 1 or 2")
	var mean_run := chests * ScrollRun.chest_mean(cfg)
	check(absf(mean_run - 35.0 / 6.0) < 0.01, "about 6 gems a crossing (%.2f)" % mean_run)
	var cat := Store.catalog()
	for id in ["bolt_red", "bolt_green", "slime_knight"]:
		var price: int = Store.item(cat, id)["price"]["amount"]
		var runs := price / mean_run
		check(runs >= 1.5 and runs <= 5.0, "%s takes %.1f crossings" % [id, runs])
	var total := 0
	var n := 400
	var rare := 0
	var opened := 0
	for seed_value in n:
		var run := ScrollRun.new(area, Content.grades()[1], seed_value + 1)
		while run.phase != ScrollRun.CLEARED:
			if run.phase == ScrollRun.AWAIT_FIGHT:
				run.resolve_fight(true)
				continue
			var p := run.roll()
			var out := run.choose(p["answer_index"])
			for c in out.get("chests", []):
				opened += 1
				if c["gems"] == 2:
					rare += 1
				check(c["gems"] == 1 or c["gems"] == 2, "a chest gave %d" % c["gems"])
		total += run.gems
	var measured := float(total) / n
	check(absf(measured - mean_run) < 0.3, "mean gems per run %.2f, expected %.2f" % [measured, mean_run])
	var share := float(rare) / opened
	check(share > 0.12 and share < 0.22, "2 gems in %.2f of chests, expected 1 in 6" % share)
	return true


## Red and Green Bolt are the robot dragon recolored in code: same size, the
## outline and teal eyes kept, the body in the new hue.
func test_bolt_colors_recolor_the_body_only() -> bool:
	var Look = load("res://game/ui/look.gd")
	var base: Image = Look.hero_texture("robodragon").get_image()
	for id in ["bolt_red", "bolt_green"]:
		var img: Image = Look.hero_texture(id).get_image()
		eq(img.get_size(), base.get_size(), "%s same size as Bolt" % id)
		var changed := 0
		var kept_teal := true
		var kept_dark := true
		for y in base.get_height():
			for x in base.get_width():
				var a: Color = base.get_pixel(x, y)
				var b: Color = img.get_pixel(x, y)
				if a.a == 0.0:
					continue
				if not a.is_equal_approx(b):
					changed += 1
				if a.v < 0.16 and not a.is_equal_approx(b):
					kept_dark = false
				if a.g > a.r + 0.12 and a.g >= a.b - 0.02 and not a.is_equal_approx(b):
					kept_teal = false
		check(changed > 1500, "%s body recolored (%d px)" % [id, changed])
		check(kept_teal, "%s keeps the teal eyes" % id)
		check(kept_dark, "%s keeps the outline" % id)
	var red: Image = Look.hero_texture("bolt_red").get_image()
	var green: Image = Look.hero_texture("bolt_green").get_image()
	var rs := Vector3.ZERO
	var gs := Vector3.ZERO
	for y in red.get_height():
		for x in red.get_width():
			var c: Color = red.get_pixel(x, y)
			if c.a > 0.0:
				rs += Vector3(c.r, c.g, c.b)
			c = green.get_pixel(x, y)
			if c.a > 0.0:
				gs += Vector3(c.r, c.g, c.b)
	check(rs.x > rs.y and rs.x > rs.z, "Red Bolt is red overall %s" % rs)
	check(gs.y > gs.x and gs.y > gs.z, "Green Bolt is green overall %s" % gs)
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
	eq(Store.state(cat, s, "gold"), Store.LOCKED, "gold dice")
	return true


func test_buy_the_slime() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	s["gems"] = 24
	check(not Store.can_afford(cat, s, "slime_knight"), "24 is not enough")
	check(not Store.buy(cat, s, "slime_knight"), "can't buy at 24")
	eq(s["gems"], 24, "no gems taken")
	SaveData.add_gems(s, 4)
	eq(Store.state(cat, s, "slime_knight"), Store.BUY, "buyable at 28")
	check(Store.buy(cat, s, "slime_knight"), "bought")
	eq(s["gems"], 3, "25 spent")
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


func test_locked_items_cant_be_bought_or_used() -> bool:
	var cat := Store.catalog()
	var s := _fresh()
	Store.add(s, "crystals", 999)
	eq(Store.balance(s, "crystals"), 999, "crystals kept in currencies")
	eq(s["gems"], 0, "gems untouched")
	check(Store.is_locked(cat, s, "steel"), "crystals can't be earned yet")
	check(not Store.buy(cat, s, "steel"), "locked: no buy")
	check(not Store.equip(cat, s, "steel"), "not owned: no equip")
	check(not Store.equip(cat, s, "nonsense"), "unknown id")
	eq(Store.balance(s, "crystals"), 999, "nothing spent")
	return true


## A later area opens its currency in the data alone, with no code change.
func test_opening_a_currency_in_data_unlocks_its_items() -> bool:
	var cat: Dictionary = Store.catalog().duplicate(true)
	cat["currencies"]["crystals"]["open"] = true
	var s := _fresh()
	eq(Store.state(cat, s, "steel"), Store.SHORT, "open but no crystals")
	Store.add(s, "crystals", 25)
	check(Store.buy(cat, s, "steel"), "bought steel dice")
	eq(Store.balance(s, "crystals"), 5, "20 spent")
	check(Store.equip(cat, s, "steel"), "equip dice")
	eq(Store.equipped(cat, s, "dice"), "steel", "steel in use")
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
	var broken := SaveData.from_text('{"gems": 5, "owned": "oops", "currencies": 3}', "1")
	eq(broken["owned"], [], "a broken owned list resets")
	eq(broken["currencies"], {}, "a broken currencies dict resets")
	eq(broken["gems"], 5, "gems kept")
	var s2 := _fresh()
	s2["gems"] = 35
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
