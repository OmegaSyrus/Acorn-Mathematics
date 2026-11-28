## Autoload (art grid plan 2026-11-24): puts the sharp-pixels shader on every
## canvas item in the game, the stills tools included, see
## sharp_pixels.gdshader. Items that bring their own material keep it.
extends Node

var _mat: ShaderMaterial


func _enter_tree() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/ui/sharp_pixels.gdshader")
	get_tree().node_added.connect(_on_added)
	_walk(get_tree().root)


func _walk(n: Node) -> void:
	_on_added(n)
	for c in n.get_children():
		_walk(c)


func _on_added(n: Node) -> void:
	var ci := n as CanvasItem
	if ci != null and ci.material == null:
		ci.material = _mat
