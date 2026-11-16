## Writes this build's manifest (logic/core/manifest.gd) to
## docs/contract/samples/manifest.json. Run after a version or content change:
##   godot --headless --path . --script tools/contract/make_manifest.gd
## tests/test_contract.gd fails while the sample is out of date.
extends SceneTree

const Manifest := preload("res://logic/core/manifest.gd")


func _init() -> void:
	var f := FileAccess.open("res://docs/contract/samples/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(Manifest.build(), " ", false) + "\n")
	f.close()
	print("wrote docs/contract/samples/manifest.json")
	quit()
