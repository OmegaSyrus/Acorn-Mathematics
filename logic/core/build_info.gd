## Which game and build this is, for the play log, snapshots and the
## manifest (docs/contract). APP and CODE must match export_presets.cfg's
## version/name and version/code (tests/test_contract.gd checks).
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

## The permanent game id (docs/contract/README.md, Ids).
const GAME := "acorn-math"
const TITLE := "Acorn Mathematics"
const APP := "0.27.0"
const CODE := 46

static var _cv := 0


## The content version: content/levels.json's "version".
static func cv() -> int:
	if _cv == 0:
		var data = JsonUtil.load_file("res://content/levels.json")
		_cv = maxi(1, int(data.get("version", 1))) if data is Dictionary else 1
	return _cv
