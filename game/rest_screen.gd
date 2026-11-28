## The gentle stop (family settings, addons/acorn_family/family_limits.gd):
## the day's minutes are used up, or it is past bedtime. Ellwynn and the
## player's hero say goodnight; everything is saved before this shows. The
## only way on is the small Grown-ups button, which asks for the parent PIN
## (main.gd), and a grown-up's yes lasts until the next morning.
extends Node2D

signal grown_up

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const M3 := preload("res://game/ui/m3.gd")
const Look := preload("res://game/ui/look.gd")

const ELLWYNN := preload("res://art/ellwynn/fullbody-closed.png")
const GROWN_UP_RECT := Rect2(616, 464, 208, 60)
const NIGHT := Color(0.06, 0.07, 0.16)
const DAY := Color(0.12, 0.1, 0.08)

## "daily" or "bedtime".
var reason := "daily"
var picture := ""
var choice: ChoiceWidget
var _t := 0.0


func setup(why: String, hero_picture: String) -> void:
	reason = why
	picture = hero_picture


static func title_for(why: String) -> String:
	return "It's bedtime!" if why == "bedtime" else "Time to rest!"


func _ready() -> void:
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	if picture != "":
		Look.hero_texture(picture)
	choice.present([GROWN_UP_RECT], 0)
	await choice.picked
	grown_up.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var night := reason == "bedtime"
	draw_rect(Rect2(-480, -100, 1920, 740), NIGHT if night else DAY)
	if night:
		for i in 18:
			var at := Vector2(140 + (i * 137) % 690, 30 + (i * 71) % 200)
			draw_circle(at, 1.5 + 0.8 * sin(_t * 2.0 + i), Color(1, 1, 0.85, 0.8))
		draw_circle(Vector2(760, 90), 34, Color(1.0, 0.95, 0.75))
		draw_circle(Vector2(776, 80), 30, NIGHT)
	var bob := 3.0 * sin(_t * 2.0)
	draw_texture(ELLWYNN, Vector2(170, 236 + bob).round())
	if picture != "":
		var tex := Look.hero_texture(picture)
		if tex != null:
			draw_texture(tex, Vector2(360, 492 - tex.get_height()).round())
	M3.text_center(self, Rect2(360, 150, 460, 70), title_for(reason), M3.DISPLAY, M3.PRIMARY)
	M3.text_center(self, Rect2(360, 232, 460, 50), "Come back tomorrow.", M3.HEADLINE, M3.ON_SURFACE)
	M3.text_center(self, Rect2(360, 296, 460, 36), "Everything is saved.", M3.BODY, M3.ON_SURFACE_VARIANT)
	M3.button(self, GROWN_UP_RECT, "Grown-ups", M3.Style.TEXT)
