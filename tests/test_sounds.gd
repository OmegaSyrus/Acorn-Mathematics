## Phase 3 sound effects and music folders: every sound id loads, drop-in
## overrides replace built-ins, tone() call sites route to named sounds,
## and the music folders list, shuffle and fall back to Lava
## (game/beeper.gd, game/music.gd).
extends "res://tests/support/test_case.gd"

const BeeperScript := preload("res://game/beeper.gd")
const MusicScript := preload("res://game/music.gd")
const FIX := "res://tests/support/audio_fixtures/"


func test_every_builtin_id_loads() -> bool:
	var found := BeeperScript.takes_in(BeeperScript.BUILTIN_DIR)
	for id in BeeperScript.IDS:
		check(found.has(id), "built-in sound %s exists" % id)
		for path in found.get(id, []):
			var s = load(path)
			check(s is AudioStream, "%s loads as audio" % path)
			if s is AudioStream:
				check(s.get_length() > 0.02 and s.get_length() < 3.0, "%s length %.2f" % [path, s.get_length()])
	for id in found:
		check(id in BeeperScript.IDS, "built-in file %s is a listed id" % id)
	# the sounds that repeat a lot have takes to vary between
	for id in ["roll", "hop", "peg"]:
		check(found.get(id, []).size() >= 3, "%s has 3+ takes" % id)
	return true


func test_real_scan_covers_every_id() -> bool:
	var s := BeeperScript.scan(BeeperScript.BUILTIN_DIR, BeeperScript.SFX_DIR)
	for id in BeeperScript.IDS:
		check(not s.get(id, []).is_empty(), "scan has %s" % id)
	return true


func test_id_of_names() -> bool:
	eq([BeeperScript.id_of("roll.ogg"), BeeperScript.id_of("roll_2.ogg"), BeeperScript.id_of("Roll_3.MP3"),
			BeeperScript.id_of("stone_pick.wav"), BeeperScript.id_of("stone_pick_2.ogg"),
			BeeperScript.id_of("res://audio/sfx/chest_open.mp3")],
			["roll", "roll", "roll", "stone_pick", "stone_pick", "chest_open"], "ids from file names")
	# every id can be dropped in under its own name, as one take or several
	for id in BeeperScript.IDS:
		for name in ["%s.ogg" % id, "%s.MP3" % id, "%s_2.wav" % id, "%s_10.ogg" % id]:
			check(BeeperScript.id_of(name) == id, "%s names %s" % [name, id])
	return true


func test_overrides_replace_builtins() -> bool:
	var s := BeeperScript.scan(FIX + "sfx/builtin/", FIX + "sfx/")
	eq(s.keys().size(), 4, "roll, gem, stone_pick, new_thing")
	# roll: the dropped-in takes replace both built-in ones, in take order
	eq((s["roll"] as Array).map(func(p): return String(p).get_file()), ["Roll.WAV", "roll_3.wav"], "roll overridden")
	eq((s["gem"] as Array).map(func(p): return String(p).get_file()), ["gem.mp3"], "gem overridden by an mp3")
	eq(s["stone_pick"], [FIX + "sfx/builtin/stone_pick.ogg"], "no override keeps the built-in")
	check(s.has("new_thing"), "a dropped-in file adds a new id")
	for id in s:
		for path in s[id]:
			check(load(path) is AudioStream, "%s resolves" % path)
	check(not s.has("notes"), "non-audio files ignored")
	eq(BeeperScript.takes_in(FIX + "nowhere/"), {}, "a missing folder is empty")
	return true


func test_takes_never_repeat() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var takes := ["a", "b", "c"]
	var last := ""
	var seen := {}
	for i in 300:
		var t := BeeperScript.pick_take(takes, last, rng)
		check(t != last, "take %d repeated %s" % [i, t])
		last = t
		seen[t] = true
	eq(seen.size(), 3, "all takes used")
	eq(BeeperScript.pick_take(["only"], "only", rng), "only", "one take plays again")
	return true


func test_tone_call_sites_route_to_sounds() -> bool:
	var cases := [
		# [freq, dur, vol, expected id]
		[880.0, 0.06, -8.0, "peek"], [260.0, 0.1, -8.0, "lantern"], [1200.0, 0.08, -10.0, "block"],
		[330.0, 0.12, -10.0, "miss"], [220.0, 0.15, -10.0, "crack"], [660.0, 0.08, -10.0, "tap"],
		[330.0, 0.08, -10.0, "nope"], [440.0, 0.08, -10.0, "tap"], [523.0, 0.07, -10.0, "stone_pick"],
		[784.0, 0.09, -10.0, "select"], [196.0, 0.16, -10.0, "wrong"], [165.0, 0.2, -10.0, ""],
		[880.0, 0.08, -8.0, "chest_open"], [880.0, 0.08, -10.0, "tap"], [523.0, 0.1, -10.0, "bucket"],
		[150.0, 0.04, -20.0, "whiff"], [880.0, 0.1, -10.0, "peg_mod"], [300.0, 0.03, -22.0, "peg"],
		[495.0, 0.12, -10.0, "reveal"], [990.0, 0.14, -10.0, "heart"], [1320.0, 0.1, -8.0, "heart_land"],
		[330.0, 0.06, -10.0, "tap"], [520.0, 0.05, -10.0, "tap"],
	]
	for c in cases:
		var r := BeeperScript.route_tone(c[0], c[1], c[2])
		check(r[0] == c[3], "tone(%s, %s, %s) -> %s, want %s" % [c[0], c[1], c[2], r[0], c[3]])
	# gem runs climb: the pitch follows the asked frequency
	for k in 8:
		var g := BeeperScript.route_tone(1046.0 * pow(1.12, k), 0.09, -10.0)
		check(g[0] == "gem" and absf(g[2] - pow(1.12, k)) < 0.01, "gem %d pitch %s" % [k, g])
		var b := BeeperScript.route_tone(1046.0 * pow(1.06, k), 0.07, -12.0)
		check(b[0] == "coin" and absf(b[2] - pow(1.06, k)) < 0.01, "bucket gem %d pitch %s" % [k, b])
	# anything else: a mallet note at that pitch, at the asked loudness
	var m := BeeperScript.route_tone(587.0, 0.2, -14.0)
	eq([m[0], m[1]], ["mallet", -4.0], "unknown tone falls back to the mallet")
	check(absf(m[2] - 587.0 / 440.0) < 0.001, "mallet pitch")
	for id in BeeperScript.TONE_MAP.values().map(func(e): return e[0]):
		check(id == "" or id in BeeperScript.IDS, "mapped id %s exists" % id)
	for second in BeeperScript.PAIRS:
		check(BeeperScript.TONE_MAP.has(second) and BeeperScript.TONE_MAP.has(BeeperScript.PAIRS[second]), "pair %s" % second)
	return true


func test_count_climbs_a_major_scale() -> bool:
	var p := []
	for n in range(1, 9):
		p.append(snappedf(BeeperScript.count_pitch(n), 0.001))
	eq(p, [1.0, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2.0], "do re mi fa so la ti do")
	check(BeeperScript.count_pitch(40) == BeeperScript.count_pitch(14), "clamped at the top")
	return true


func test_music_folders_list_songs() -> bool:
	eq(MusicScript.songs_in(FIX + "music", "lava_caves").map(func(p): return String(p).get_file()),
			["a-song.wav", "b-song.ogg", "c.mp3"], "any name and type, sorted")
	eq(MusicScript.songs_in(FIX + "music", "bog"), [], "an empty folder (only .gitkeep)")
	eq(MusicScript.songs_in(FIX + "music", "space"), [], "a missing folder")
	for p in MusicScript.songs_in(FIX + "music", "lava_caves"):
		check(load(p) is AudioStream, "%s loads" % p)
	return true


func test_music_fallback_to_lava() -> bool:
	var root := FIX + "music"
	var lava := MusicScript.songs_in(root, "lava_caves")
	eq(MusicScript.world_songs(root, "crystal_mines").map(func(p): return String(p).get_file()), ["only.ogg"], "own songs")
	eq(MusicScript.world_songs(root, "bog"), lava, "empty folder plays Lava")
	eq(MusicScript.world_songs(root, "space"), lava, "missing folder plays Lava")
	eq(MusicScript.world_songs(root, "nowhere_yet"), lava, "unknown world plays Lava")
	# fallback worlds share the Lava list, so the song carries on between them
	eq([MusicScript.list_name_for(root, "bog"), MusicScript.list_name_for(root, "space"),
			MusicScript.list_name_for(root, "lava_caves"), MusicScript.list_name_for(root, "crystal_mines")],
			["lava_caves", "lava_caves", "lava_caves", "crystal_mines"], "list names")
	return true


func test_music_shuffle_never_repeats() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tracks := ["a", "b", "c", "d"]
	var last := ""
	var seen := {}
	for i in 400:
		var t := MusicScript.pick_next(tracks, last, rng)
		check(t != last, "song %d repeated" % i)
		last = t
		seen[t] = true
	eq(seen.size(), 4, "every song plays")
	eq(MusicScript.pick_next(["menu"], "menu", rng), "menu", "a one-song list plays it again")
	eq(MusicScript.pick_next([], "", rng), "", "no songs")
	return true


func test_real_music_folders() -> bool:
	var menu := MusicScript.songs_in(MusicScript.DIR, "menu")
	eq(menu, ["res://audio/music/menu/menu-welcome-to-math-land.mp3"], "menu song")
	var lava := MusicScript.songs_for("lava_caves")
	eq(lava.size(), 5, "five Lava songs")
	for p in lava:
		check(String(p).begins_with("res://audio/music/lava_caves/"), "%s in lava folder" % p)
	for w in MusicScript.WORLDS:
		var songs := MusicScript.songs_for(w)
		check(not songs.is_empty(), "%s has songs to play" % w)
		var own := MusicScript.songs_in(MusicScript.DIR, w)
		check(songs == (own if not own.is_empty() else lava), "%s plays its own or Lava" % w)
	# the menu song loops in the stream itself
	var s: AudioStream = load(menu[0])
	MusicScript.set_loop(s, true)
	check(s.get("loop") == true, "menu mp3 loops")
	MusicScript.set_loop(s, false)
	check(s.get("loop") == false, "loop off again")
	return true


func test_worlds_match_content() -> bool:
	var f := FileAccess.open("res://content/worlds.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	var ids := []
	for w in (data if data is Array else data.get("worlds", [])):
		ids.append(String(w["id"]))
	eq(ids, MusicScript.WORLDS, "a music folder per world")
	for id in ids:
		check(DirAccess.dir_exists_absolute(MusicScript.DIR + id), "audio/music/%s/ exists" % id)
	return true
