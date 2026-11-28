## Where the family backend is, and the add-on's file names. One setting
## picks the server, so a build can point at staging or production:
##   1. the ACORN_FAMILY_URL environment variable (desktop runs, the e2e script),
##   2. the project setting acorn_family/base_url (project.godot),
##   3. DEFAULT_BASE_URL (staging until the domain exists).
## Every path the add-on calls is relative to it (docs/contract/api-v1.md).
extends RefCounted

const DEFAULT_BASE_URL := "https://maphrtpqbqmjfmhgqonq.supabase.co/functions/v1/api/v1"
const SETTING := "acorn_family/base_url"
const ENV := "ACORN_FAMILY_URL"

## The device token (never backed up; it is also tied to the device id, so a
## copied file is ignored on another tablet).
const TOKEN_FILE := "device_token.json"
## Upload position, consent, the profile-to-child map, cached settings,
## minutes played today.
const STATE_FILE := "family_state.json"


static func base_url() -> String:
	var env := OS.get_environment(ENV).strip_edges()
	if env != "":
		return env.rstrip("/")
	if ProjectSettings.has_setting(SETTING):
		var s := str(ProjectSettings.get_setting(SETTING, "")).strip_edges()
		if s != "":
			return s.rstrip("/")
	return DEFAULT_BASE_URL
