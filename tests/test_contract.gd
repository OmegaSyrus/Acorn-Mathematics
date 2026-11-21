## The family data contract (docs/contract): every sample validates, and what
## the game really writes (play log lines, device file, roster, save,
## snapshot, manifest) validates against the same schemas.
extends "res://tests/support/test_case.gd"

const SchemaCheck := preload("res://tests/support/schema_check.gd")
const PlayLog := preload("res://game/play_log.gd")
const DeviceInfo := preload("res://logic/core/device_info.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Manifest := preload("res://logic/core/manifest.gd")
const BuildInfo := preload("res://logic/core/build_info.gd")
const Skills := preload("res://logic/core/skills.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const AttackGen := preload("res://logic/fight/attack_gen.gd")
const SeededRng := preload("res://logic/core/rng.gd")

const C := "res://docs/contract/"

var notes := []


func _schema(name: String) -> Dictionary:
	return JsonUtil.load_file(C + name)


func _valid(doc: Variant, schema_file: String, what: String) -> void:
	var errs := SchemaCheck.errors(doc, _schema(schema_file))
	check(errs.is_empty(), "%s: %s" % [what, "; ".join(errs.slice(0, 5))])


func test_samples_validate() -> bool:
	var pairs := {
		"samples/event-answer.v2.json": "schemas/event.v2.schema.json",
		"samples/event-run.v2.json": "schemas/event.v2.schema.json",
		"samples/device.json": "schemas/device.v1.schema.json",
		"samples/profiles.json": "schemas/profiles.v1.schema.json",
		"samples/snapshot.json": "schemas/snapshot.v1.schema.json",
		"samples/settings.json": "schemas/settings.v1.schema.json",
		"samples/manifest.json": "schemas/manifest.v1.schema.json",
		"samples/acorn-save.v2.json": "games/acorn-math/save.v2.schema.json",
	}
	for s in pairs:
		_valid(JsonUtil.load_file(C + s), pairs[s], s)
	for line in FileAccess.get_file_as_string(C + "samples/play_log.v2.jsonl").split("\n", false):
		_valid(JsonUtil.normalize(JSON.parse_string(line)), "schemas/event.v2.schema.json", "play_log line")
	return true


func test_checker_rejects_bad_documents() -> bool:
	var line: Dictionary = JsonUtil.load_file(C + "samples/event-answer.v2.json")
	var schema := _schema("schemas/event.v2.schema.json")
	for k in ["dev", "seq", "skill"]:
		var bad := line.duplicate()
		bad.erase(k)
		check(not SchemaCheck.errors(bad, schema).is_empty(), "missing %s is caught" % k)
	var bad_dev := line.duplicate()
	bad_dev["dev"] = "tablet-1"
	check(not SchemaCheck.errors(bad_dev, schema).is_empty(), "a bad device id is caught")
	var both := line.duplicate()
	both["kind"] = "event"
	check(not SchemaCheck.errors(both, schema).is_empty(), "an event without its name is caught")
	return true


func _ctx() -> Dictionary:
	return {"dev": "d_0123456789abcdef", "profile": "p_0123456789ab", "seq": 5, "boot": 2, "mono_ms": 1234,
			"world": "lava_caves", "area": "lava_scroll", "level": 1, "level_id": 1}


func test_game_play_log_lines_validate() -> bool:
	var shown := PlayLog.stone_shown({"op": "add", "dice": [3, 2], "answer": 5, "choices": [1, 2, 3, 4, 5]})
	var a: Variant = JsonUtil.normalize(JSON.parse_string(PlayLog.to_line(PlayLog.answer_entry(1763000000, _ctx(), "stone", shown, 5, 4, 2.0))))
	_valid(a, "schemas/event.v2.schema.json", "answer line")
	var e: Variant = JsonUtil.normalize(JSON.parse_string(PlayLog.to_line(PlayLog.event_entry(1763000000, _ctx(), "run_start"))))
	_valid(e, "schemas/event.v2.schema.json", "event line")
	return true


func test_game_documents_validate() -> bool:
	var d := DeviceInfo.from_text("", "hw", 100)
	_valid(d, "schemas/device.v1.schema.json", "device file")
	var r := Profiles.new_roster(100)
	Profiles.add_child(r, 101)
	Profiles.ensure_guest(r, 102)
	Profiles.set_pin(r, "1234")
	_valid(JsonUtil.normalize(JSON.parse_string(Profiles.to_text(r))), "schemas/profiles.v1.schema.json", "roster")
	var s := SaveData.new_profile(Profiles.active(r)["id"])
	_valid(JsonUtil.normalize(JSON.parse_string(SaveData.to_text(s))), "games/acorn-math/save.v2.schema.json", "save")
	var w := SaveData.snapshot(s, d["dev"], 1, 100)
	_valid(JsonUtil.normalize(JSON.parse_string(JSON.stringify(w))), "schemas/snapshot.v1.schema.json", "snapshot")
	_valid(JsonUtil.normalize(JSON.parse_string(JSON.stringify(Manifest.build()))), "schemas/manifest.v1.schema.json", "manifest")
	return true


func test_manifest_sample_is_this_build() -> bool:
	var sample: Dictionary = JsonUtil.load_file(C + "samples/manifest.json")
	var m := Manifest.build()
	for k in ["game", "title", "app", "code", "settings", "skills", "pictures", "picture_labels"]:
		eq(sample[k], m[k], "samples/manifest.json %s (run tools/contract/make_manifest.gd)" % k)
	check(not m.has("levels_unlock") and not JSON.stringify(m["settings"]).contains("world"),
			"no Level or world unlock for parents")
	return true


func test_build_info_matches_export() -> bool:
	# CRLF on a Windows checkout (core.autocrlf): compare by lines
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg").replace("
", "
")
	check(cfg.contains('version/name="%s"' % BuildInfo.APP), "export_presets version/name is " + BuildInfo.APP)
	check(cfg.contains("version/code=%d\n" % BuildInfo.CODE), "export_presets version/code is %d" % BuildInfo.CODE)
	return true


## Every question the game can ask names a skill from the shared list.
func test_every_question_has_a_known_skill() -> bool:
	var known := Skills.ids()
	var seen := {}
	var levels := Content.levels()
	var area_of := {}
	for w in Content.worlds():
		area_of[w["id"]] = str(w.get("area", "lava_scroll"))
	for id in levels:
		var lv: Dictionary = levels[id]
		var area_id: String = area_of.get(lv.get("world", ""), "lava_scroll")
		for seed_value in range(1, 6):
			var run := ScrollRun.new(Content.area(area_id), lv, seed_value * 31 + int(id))
			var k := 0
			while run.phase != ScrollRun.CLEARED and k < 40:
				if run.phase == ScrollRun.AWAIT_FIGHT:
					run.resolve_fight(true)
					continue
				var p := run.roll()
				var sk := Skills.of("stone", PlayLog.stone_shown(p), int(p["answer"]))
				seen[sk] = true
				check(known.has(sk), "level %d: %s for %s" % [id, sk, PlayLog.stone_shown(p)["q"]])
				run.choose(p["answer_index"])
				k += 1
	for kind in ["count 4", "3 + 2 = ?", "2 + ? = 6", "5 - 2 = ?"]:
		var sk := Skills.of("fight", {"q": kind, "dice": [5, 2]}, 3)
		check(known.has(sk), "fight %s: %s" % [kind, sk])
	for rule in ["match", "sum", "difference"]:
		check(known.has(Skills.of("boss", {"rule": rule, "target": 5}, 2)), "boss " + rule)
	notes.append("skills seen on the stones: %s" % ", ".join(seen.keys()))
	return true


func test_skill_examples() -> bool:
	eq(Skills.of("stone", {"q": "3 + 2 = ?", "dice": [3, 2]}, 5), "add.within6", "small sum")
	eq(Skills.of("stone", {"q": "6 + 3 = ?", "dice": [6, 3]}, 9), "add.within10", "sum to 10")
	eq(Skills.of("stone", {"q": "6 + 6 = ?", "dice": [6, 6]}, 12), "add.within20", "sum to 12")
	eq(Skills.of("stone", {"q": "6 - 2 = ?", "dice": [6, 2]}, 4), "sub.within6", "take away")
	eq(Skills.of("stone", {"q": "3 + ? = 7", "dice": [3, 4]}, 4), "missing_addend.within10", "face down")
	eq(Skills.of("stone", {"q": "3 + 4 - 2 = ?", "dice": [3, 4, 2]}, 5), "addsub3.within20", "three dice")
	eq(Skills.of("fight", {"q": "count 4", "dice": [4]}, 4), "count.to6", "count")
	eq(Skills.of("boss", {"rule": "match", "target": 4}, 4), "numeral.match.to6", "boss match")
	return true
