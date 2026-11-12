## How each world looks (Terrence 2026-11-08: Crystal Mines and the Bog are
## playable with their own art). An area file names its world; the crossing,
## the fights and the boss look that world up here. Art from PixelLab, picked
## by Terrence (art/crystal/README.md, art/bog/README.md). Every character is
## drawn 1 art pixel = 1 unit (Look.CHAR_PX); backdrops are 320x180 at 3x.
extends RefCounted

const DEFAULT := "lava_caves"

## Monster art by monster id, for the crossing, fights and duels.
const MONSTER_ART := {
	"blorp": "res://art/lava/blorp-idle.png",
	"craggy": "res://art/lava/craggy.png",
	"surtling": "res://art/lava/surtling.png",
	"mimic": "res://art/lava/mimic.png",
	"lava_miniboss": "res://art/lava/surtling-chief.png",
	"knocker": "res://art/crystal/knocker.png",
	"gem_dwarf": "res://art/crystal/gem-dwarf.png",
	"svartalf": "res://art/crystal/svartalf.png",
	"crystal_miniboss": "res://art/crystal/lantern-lord.png",
	"wispling": "res://art/bog/wispling.png",
	"nixie": "res://art/bog/nixie.png",
	"draugr": "res://art/bog/draugr.png",
	"tiddy_mun": "res://art/bog/tiddy-mun.png",
	"bog_miniboss": "res://art/bog/wisp-pair.png",
	"star_squirrel": "res://art/space/star-squirrel.png",
	"moon_hobgoblin": "res://art/space/moon-hobgoblin.png",
	"fenrir_pup": "res://art/space/fenrir-pup.png",
	"space_miniboss": "res://art/space/ratatoskr.png",
}

## Per world:
##   backdrop:   "strip" (one 1920x180 strip at 3x) or a 320x180 tile path at 3x
##   stones:     sprites cycled along the crossing
##   stone_top:  true = the sprite's top row is where the hero stands (the
##               stalagmites rise out of the pit); false = the sprite's
##               waterline row `waterline` sits on the water line (rocks, tussocks)
##   sink_depth: how far a wrong stone drops (a stalagmite collapses all the way)
##   ceiling:    sprites hung from the top of the screen, each `ceiling_step` wide
##   glow:       the lava shimmer over the bottom of the screen
##   ledge_tint: the start and far-shore ledges (basalt tile) tinted to fit
##   monsters:   ids that belong to this world (picks the fight room)
##   boss_head / boss_arm and where they sit, the treasure room behind the boss
##   sky:        (Space) the colour above the backdrop at half size, in place
##               of the cave roof, with twinkling stars drawn over it
##   stars:      twinkling stars over the whole crossing
const THEMES := {
	"lava_caves": {
		"backdrop": "strip",
		"stones": ["res://art/lava/rock-1.png", "res://art/lava/rock-2.png", "res://art/lava/rock-3.png"],
		"stone_top": false, "waterline": 64.0, "sink_depth": 46.0,
		"ceiling": [], "ceiling_step": 0.0,
		"glow": true, "ledge_tint": Color(1, 1, 1),
		"monsters": ["blorp", "craggy", "surtling", "mimic", "lava_miniboss"],
		"fight_bg": "res://art/lava/fight-bg.png",
		"boss_head": "res://art/boss/skeleton-dragon.png", "head_at": Vector2(716, -34),
		"boss_arm": "res://art/boss/bone-arm.png", "arm_at": Vector2(700, 196),
		"treasure": "res://art/boss/treasure-cave.png", "boss_label": "Dragon",
		"board_tint": Color(1, 1, 1, 0.9),
	},
	"crystal_mines": {
		"backdrop": "res://art/crystal/cave-bg.png",
		"stones": ["res://art/crystal/stalagmite-1.png", "res://art/crystal/stalagmite-wide.png", "res://art/crystal/stalagmite-0.png"],
		"stone_top": true, "waterline": 0.0, "sink_depth": 150.0,
		"ceiling": ["res://art/crystal/ceiling-0.png", "res://art/crystal/ceiling-1.png",
				"res://art/crystal/ceiling-2.png", "res://art/crystal/ceiling-3.png"],
		"ceiling_step": 240.0,
		"glow": false, "ledge_tint": Color(0.62, 0.72, 0.95),
		"monsters": ["knocker", "gem_dwarf", "svartalf", "crystal_miniboss"],
		"fight_bg": "res://art/crystal/fight-bg.png",
		"boss_head": "res://art/crystal/knocker-king.png", "head_at": Vector2(700, -40),
		"boss_arm": "res://art/crystal/king-hammer.png", "arm_at": Vector2(728, 300),
		"treasure": "res://art/crystal/treasure-room.png", "boss_label": "Knocker King",
		"board_tint": Color(0.7, 0.75, 1.0, 0.9),
	},
	"bog": {
		"backdrop": "res://art/bog/bog-bg.png",
		"stones": ["res://art/bog/tussock-0.png", "res://art/bog/log-0.png", "res://art/bog/peat-1.png",
				"res://art/bog/tussock-1.png", "res://art/bog/log-1.png", "res://art/bog/peat-0.png"],
		"stone_top": false, "waterline": 58.0, "sink_depth": 46.0,
		"ceiling": [], "ceiling_step": 0.0,
		"glow": false, "ledge_tint": Color(0.6, 0.62, 0.45),
		"monsters": ["wispling", "nixie", "draugr", "tiddy_mun", "bog_miniboss"],
		"fight_bg": "res://art/bog/fight-bg.png",
		"boss_head": "res://art/bog/jenny-greenteeth.png", "head_at": Vector2(690, -40),
		"boss_arm": "res://art/bog/jenny-arm.png", "arm_at": Vector2(700, 230),
		"treasure": "res://art/bog/treasure-room.png", "boss_label": "Jenny",
		"board_tint": Color(0.75, 0.95, 0.7, 0.9),
		"bubble": Color(0.65, 0.8, 0.5),
	},
	# Space (2026-11-12): star stones float over the clouds; a wrong one falls
	# away into the dark with the hero on it (like a stalagmite, no water)
	"space": {
		"backdrop": "res://art/space/space-bg.png",
		"stones": ["res://art/space/stone-0.png", "res://art/space/stone-1.png", "res://art/space/stone-2.png"],
		"stone_top": true, "waterline": 0.0, "sink_depth": 170.0,
		"ceiling": [], "ceiling_step": 0.0,
		"glow": false, "ledge_tint": Color(0.5, 0.45, 0.95),
		"sky": Color(0.027, 0.024, 0.1), "stars": true,
		"monsters": ["star_squirrel", "moon_hobgoblin", "fenrir_pup", "space_miniboss"],
		"fight_bg": "res://art/space/fight-bg.png",
		"boss_head": "res://art/space/fenrir.png", "head_at": Vector2(716, -44),
		"boss_arm": "res://art/space/fenrir-paw.png", "arm_at": Vector2(738, 236),
		"treasure": "res://art/space/treasure-room.png", "boss_label": "Fenrir",
		"board_tint": Color(0.75, 0.7, 1.0, 0.9),
	},
}


static func get_theme(world_id: String) -> Dictionary:
	return THEMES.get(world_id, THEMES[DEFAULT])


## The world a monster belongs to (its fight room), Lava Caves if unknown.
static func world_of_monster(monster_id: String) -> String:
	for w in THEMES:
		if THEMES[w]["monsters"].has(monster_id):
			return w
	return DEFAULT


static func monster_texture(monster_id: String) -> Texture2D:
	return load(MONSTER_ART.get(monster_id, MONSTER_ART["blorp"]))
