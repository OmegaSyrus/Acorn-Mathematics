## The app going to the background and coming back, and the Android back
## gesture. main.gd adds one of these and fills in the callables.
##
## Back never quits (project.godot sets application/config/quit_on_go_back
## to false, and this sets the tree's flag again): a child swiping back
## mid-crossing would lose the run. The request is taken and nothing happens,
## on every screen.
##
## Paused (APPLICATION_PAUSED, or FOCUS_OUT on a tablet, where the
## notification shade or the home button take focus): the save is written and
## the music paused. Resumed (RESUMED, or FOCUS_IN on a tablet): the music
## plays on. A pause and a resume are logged once each, however many of the
## notifications arrive. On a desktop, losing focus only saves.
extends Node

const PlayLog := preload("res://game/play_log.gd")

## Writes the save (main.gd: SaveStore.write).
var save_now := Callable()
var pause_music := Callable()
var resume_music := Callable()
## The tablet rule for focus; tests set it either way.
var mobile := OS.has_feature("mobile")
var paused := false
var back_requests := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false


## What a notification means here: "pause", "resume", "back", "save" (a
## desktop focus loss) or "".
static func action_for(what: int, on_mobile: bool) -> String:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			return "pause"
		NOTIFICATION_APPLICATION_RESUMED:
			return "resume"
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			return "pause" if on_mobile else "save"
		NOTIFICATION_APPLICATION_FOCUS_IN:
			return "resume" if on_mobile else ""
		NOTIFICATION_WM_GO_BACK_REQUEST:
			return "back"
	return ""


func _notification(what: int) -> void:
	match action_for(what, mobile):
		"pause":
			if paused:
				return
			paused = true
			_call(save_now)
			_call(pause_music)
			PlayLog.event("app_paused")
		"resume":
			if not paused:
				return
			paused = false
			_call(resume_music)
			PlayLog.event("app_resumed")
		"save":
			_call(save_now)
		"back":
			back_requests += 1  # taken, and nothing else


func _call(c: Callable) -> void:
	if c.is_valid():
		c.call()
