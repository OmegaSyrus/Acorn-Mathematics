extends RefCounted
## Lava Caves fighters for Phase 2. Placeholder roster: ids, names and hearts
## only. Move to content JSON when the path layer's content loader lands.
##
## STATES lists the reactions each fighter needs art for. The graybox can
## draw each as a labelled box until the real art arrives.

const STATES := [
	"idle",      ## breathing, glaring, holding the wind-up as long as needed
	"wind_up",   ## the swing starts and the dice show
	"blocked",   ## the hero's shield clangs
	"hurt",      ## the riposte lands; loses a heart
	"strike",    ## the swing lands on the hero
	"collapse",  ## out of hearts
	"gloat",     ## the hero collapsed
]

const MIMIC_TELLS := ["lid_twitch", "tongue_tip", "tooth_latch"]

const ROSTER := {
	"blorp": {"name": "Blorp the Ember Troll", "hearts": 3, "role": "monster"},
	"craggy": {"name": "Craggy the Stone Troll", "hearts": 4, "role": "monster"},
	"surtling": {"name": "Surtling", "hearts": 3, "role": "monster"},
	"mimic": {"name": "Mimic", "hearts": 3, "role": "mimic"},
	"lava_miniboss": {"name": "Surtling Chief", "hearts": 5, "role": "miniboss"},
	# Crystal Mines (2026-11-08)
	"knocker": {"name": "Knocker", "hearts": 3, "role": "monster"},
	"gem_dwarf": {"name": "Gem Dwarf", "hearts": 4, "role": "monster"},
	"svartalf": {"name": "Svartalf", "hearts": 3, "role": "monster"},
	"crystal_miniboss": {"name": "Svartalf Lantern Lord", "hearts": 5, "role": "miniboss"},
	# The Bog (2026-11-08)
	"wispling": {"name": "Wispling", "hearts": 3, "role": "monster"},
	"nixie": {"name": "Nixie", "hearts": 3, "role": "monster"},
	"tiddy_mun": {"name": "Tiddy Mun", "hearts": 3, "role": "monster"},
	"draugr": {"name": "Bog-draugr", "hearts": 4, "role": "monster"},
	"bog_miniboss": {"name": "Wisp King and Queen", "hearts": 5, "role": "miniboss"},
	# Space (2026-11-12)
	"star_squirrel": {"name": "Star Squirrel", "hearts": 3, "role": "monster"},
	"moon_hobgoblin": {"name": "Moon Hobgoblin", "hearts": 3, "role": "monster"},
	"fenrir_pup": {"name": "Fenrir's Pup", "hearts": 4, "role": "monster"},
	"space_miniboss": {"name": "Ratatoskr", "hearts": 5, "role": "miniboss"},
}


static func hearts_of(id: String) -> int:
	return ROSTER[id]["hearts"]


static func name_of(id: String) -> String:
	return ROSTER[id]["name"]
