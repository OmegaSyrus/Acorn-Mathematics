## Stills of the Material kit sample (profile plan P1), and a draw check:
## the sample and its dialog draw at the window's size with the stage
## centred as main.gd does, the filled button is the primary colour and the
## dialog's scrim darkens the page. Exit code 1 if a check fails.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 res://tools/stills/m3_stills.tscn -- --out=/tmp/shots
##   (and again with --resolution 720x540)
extends Node2D

const M3 := preload("res://game/ui/m3.gd")
const Sample := preload("res://game/ui/m3_sample.gd")

var out_dir := "/tmp"
var stage: Node2D
var failed := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(1, 0, 1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	await _frames(2)
	var shown := get_viewport_rect().size
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((shown - M3.DESIGN) / 2.0).round()
	var tag := "%dx%d" % [shown.x, shown.y]
	var s := Sample.new()
	stage.add_child(s)
	await _frames(4)
	var img := _shot("m3-sample-" + tag)
	var play: Rect2 = Sample.button_rects()[0]
	_near(img, play.position + Vector2(play.size.x - 20, 10), M3.PRIMARY, "filled Play button")
	_near(img, Vector2(4, 300) - stage.position, M3.SURFACE, "screen edge is the surface, not the clear colour")
	_near(img, Sample.tile_rect(2).position + Vector2(48, 3), M3.GOLD, "chosen tile ring")
	s.pressed = "swap"
	s.queue_redraw()
	await _frames(2)
	_shot("m3-sample-pressed-" + tag)
	s.pressed = ""
	s.dialog_open = true
	s.queue_redraw()
	await _frames(3)
	img = _shot("m3-dialog-" + tag)
	var under := img.get_pixelv(Vector2i(stage.position + play.position + Vector2(play.size.x - 20, 10)))
	_check(under.v < M3.PRIMARY.v * 0.7, "scrim darkens the page (%s)" % under)
	var rs := M3.dialog_button_rects(M3.dialog_rect(Sample.DIALOG_BODY.size()), Sample.DIALOG_LABELS)
	_near(img, rs[1].position + Vector2(rs[1].size.x / 2.0, 6), M3.ERROR_CONTAINER, "Remove is the error colour")
	print("m3 stills %s: %s" % [tag, "ok" if failed == 0 else "%d failed" % failed])
	get_tree().quit(1 if failed > 0 else 0)


## The pixel at design point `p` is close to `col`.
func _near(img: Image, p: Vector2, col: Color, what: String) -> void:
	var at := Vector2i((stage.position + p).round())
	at = at.clamp(Vector2i.ZERO, Vector2i(img.get_width() - 1, img.get_height() - 1))
	var got := img.get_pixelv(at)
	var d := absf(got.r - col.r) + absf(got.g - col.g) + absf(got.b - col.b)
	_check(d < 0.15, "%s at %s: got %s want %s" % [what, at, got.to_html(false), col.to_html(false)])


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> Image:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	return img
