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
	# Craggy is here as the 4-heart test case; which area he lives in is not decided.
	"craggy": {"name": "Craggy", "hearts": 4, "role": "monster"},
	"mimic": {"name": "Mimic", "hearts": 3, "role": "mimic"},
	"lava_miniboss": {"name": "Lava Caves miniboss", "hearts": 3, "role": "miniboss"},
}


static func hearts_of(id: String) -> int:
	return ROSTER[id]["hearts"]


static func name_of(id: String) -> String:
	return ROSTER[id]["name"]
