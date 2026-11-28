## Make a new profile (S2, three steps) or edit one (S4, after the parent
## PIN): profile plan P3, 2026-11-21. One screen with two modes, drawn with
## the Material kit (game/ui/m3.gd).
##
##   CREATE  1 Pick: the 14 looks (Profiles.PICTURES) as 96-unit tiles, 7 by
##             2, the chosen one ringed in gold with a check, and its full
##             picture under them.
##           2 Name: an outlined field in the top half (so the tablet's
##             keyboard leaves it in view), filled with "Player N", 12
##             letters, a counter. Next and Back sit just under it.
##           3 Yes: the full picture, the name, and "Yes".
##           Every step has Back and Next (Yes on the last).
##   EDIT    Name field and Save on top, the 14 tiles under it, Remove in the
##           top bar. Remove opens a dialog whose Remove has to be held for 3
##           seconds. The last child can't be removed; Guest can't be edited.
##
## The screen only emits signals. It never changes the roster or a file:
## main.gd (plan P4) does Profiles.add_child / finish_setup / rename /
## set_picture / ProfileStore.remove, the PIN check (plan D2) and the screen
## swaps. Usage:
##   var s := ProfileEditScreen.new()
##   s.setup(ProfileStore.roster, ProfileEditScreen.Mode.CREATE)
##   s.created.connect(...)  # and back
## With first_run (a fresh install's first profile) there is no way back from
## step 1, so the child goes through to Yes and main.gd calls finish_setup
## with what created() hands over.
extends Node2D

## Yes in CREATE mode. nickname is already cleaned and at most 12 letters;
## it is blank only if the child cleared the box (main.gd then keeps the
## default name). picture is one of Profiles.PICTURES.
signal created(nickname: String, picture: String)
## Save in EDIT mode (same rules for nickname and picture).
signal saved(profile_id: String, nickname: String, picture: String)
## The Remove dialog's 3 second hold finished (EDIT mode).
signal removed(profile_id: String)
## Back from step 1, from the top bar in EDIT mode, or an EDIT setup that
## can't be edited (Guest, an unknown id).
signal back

enum Mode { CREATE, EDIT }
enum Step { PICK, NAME, CONFIRM }

const M3 := preload("res://game/ui/m3.gd")
const Look := preload("res://game/ui/look.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const EllwynnRef := preload("res://game/ellwynn.gd")
const WhoScreen := preload("res://game/who_screen.gd")

const TILE := 96.0
const COLS := 7
## The tile rows: CREATE's Pick step and EDIT.
const PICK_TILE_Y := 104.0
const EDIT_TILE_Y := 224.0
## The bottom row's buttons (Back on the left, Next or Yes on the right).
const NAV_Y := 448.0
## The Name step's buttons sit just under the field, above the keyboard.
const NAME_NAV_Y := 232.0
const NAME_FIELD := Rect2(248, 112, 584, 80)
const NAME_HEAD := Rect2(128, 104, 96, 96)
const EDIT_FIELD := Rect2(128, 112, 472, 80)
const CONFIRM_CARD := Rect2(384, 104, 192, 176)
## How much of a picture a tile shows: the top 88x88, at 1:1 (never scaled).
const CROP := Vector2(88, 88)
const HOLD_S := 3.0
const DIALOG_LABELS := ["Back", "Remove"]

var mode := Mode.CREATE
var step := Step.PICK
var first_run := false
var profile_id := ""
var roster: Dictionary = {}
var picture := ""
var name_text := ""
## true when EDIT was asked for a profile that can't be edited.
var refused := false
var dialog_open := false
var hold_t := -1.0  # seconds Remove has been held, -1 when not held
var pressed := ""  # a target drawn in its pressed state (stills)
## true: Ellwynn says what to do on each CREATE step (K3 pick a picture, K4
## ask a grown-up to type the name). main.gd turns it on for a child making
## their own; the Grown-ups' screens stay silent.
var voice := false
var _spoken := -1  # the step she last spoke for

var choice: ChoiceWidget
var line: LineEdit
var _live: Array = []  # target names ChoiceWidget is showing, by index


## mode is Mode.CREATE or Mode.EDIT. profile_id is the child to edit (EDIT
## only). first_run: the fresh install's first profile (CREATE only).
func setup(r: Dictionary, m: int, id := "", first := false) -> void:
	roster = r
	mode = m as Mode
	profile_id = id
	first_run = first and mode == Mode.CREATE
	step = Step.PICK
	dialog_open = false
	hold_t = -1.0
	refused = false
	if mode == Mode.CREATE:
		if first_run:
			var kids := Profiles.children(r)
			name_text = str(kids[0]["nickname"]) if not kids.is_empty() else "Player 1"
			picture = str(kids[0]["picture"]) if not kids.is_empty() else Profiles.DEFAULT_PICTURE
		else:
			name_text = Profiles.default_name(r)
			picture = Profiles.next_free_picture(r)
	else:
		var p := Profiles.find(r, id)
		refused = p.is_empty() or bool(p.get("guest", false))
		name_text = str(p.get("nickname", ""))
		picture = str(p.get("picture", Profiles.DEFAULT_PICTURE))
	if not Profiles.PICTURES.has(picture):
		picture = Profiles.DEFAULT_PICTURE
	if is_inside_tree():
		_refresh()


## True when Remove can be used: EDIT mode and not the last child.
func can_remove() -> bool:
	return mode == Mode.EDIT and not refused and Profiles.children(roster).size() > 1


# --- layout ----------------------------------------------------------------------

static func tile_rect(i: int, top: float) -> Rect2:
	var gap := (M3.SAFE.size.x - COLS * TILE) / (COLS - 1)
	@warning_ignore("integer_division")
	var row := i / COLS
	var col := i % COLS
	return Rect2(Vector2(M3.SAFE.position.x + col * (TILE + gap), top + row * (TILE + M3.GRID)),
			Vector2(TILE, TILE))


func field_rect() -> Rect2:
	return EDIT_FIELD if mode == Mode.EDIT else NAME_FIELD


func _nav_y() -> float:
	return NAME_NAV_Y if step == Step.NAME else NAV_Y


func back_button_rect() -> Rect2:
	return M3.button_rect(Vector2(M3.SAFE.position.x + M3.GRID, _nav_y()), "Back")


func next_button_rect() -> Rect2:
	var label := "Yes" if step == Step.CONFIRM else "Next"
	var icon := M3.Icon.CHECK if step == Step.CONFIRM else M3.Icon.NONE
	var w := M3.button_width(label, icon)
	if step == Step.CONFIRM:
		w = maxf(w, 200.0)  # the last tap of the flow, made big
	return Rect2(Vector2(M3.SAFE.end.x - M3.GRID - w, _nav_y()), Vector2(w, M3.BUTTON_H))


func save_button_rect() -> Rect2:
	var w := M3.button_width("Save", M3.Icon.CHECK)
	return Rect2(Vector2(M3.SAFE.end.x - M3.GRID - w, EDIT_FIELD.position.y + (M3.FIELD_H - M3.BUTTON_H) / 2.0),
			Vector2(w, M3.BUTTON_H))


func remove_action_rect() -> Rect2:
	return M3.top_bar_action_rect(0, "Remove", M3.Icon.BIN)


func dialog_rects() -> Array:
	return M3.dialog_button_rects(M3.dialog_rect(_dialog_body().size()), DIALOG_LABELS)


func _dialog_body() -> Array:
	return ["Hold Remove for 3 seconds.", "Stars and gems on this tablet go too."]


func _shows_top_back() -> bool:
	return not (first_run and step == Step.PICK)


## Every tap target now on screen: [{name, rect}]. Names: back (top bar),
## nav_back, next, tile_0 .. tile_13, field, save, remove, dialog_back,
## dialog_remove (held, not tapped). With the dialog open only its two
## buttons count.
func targets() -> Array:
	var out := []
	if refused:
		return out
	if dialog_open:
		var rs := dialog_rects()
		out.append({"name": "dialog_back", "rect": rs[0]})
		out.append({"name": "dialog_remove", "rect": rs[1]})
		return out
	if _shows_top_back():
		out.append({"name": "back", "rect": M3.top_bar_back_rect()})
	if mode == Mode.EDIT:
		if can_remove():
			out.append({"name": "remove", "rect": remove_action_rect()})
		out.append({"name": "field", "rect": EDIT_FIELD})
		out.append({"name": "save", "rect": save_button_rect()})
		for i in Profiles.PICTURES.size():
			out.append({"name": "tile_%d" % i, "rect": tile_rect(i, EDIT_TILE_Y)})
		return out
	match step:
		Step.PICK:
			for i in Profiles.PICTURES.size():
				out.append({"name": "tile_%d" % i, "rect": tile_rect(i, PICK_TILE_Y)})
		Step.NAME:
			out.append({"name": "field", "rect": NAME_FIELD})
	if _shows_top_back():
		out.append({"name": "nav_back", "rect": back_button_rect()})
	out.append({"name": "next", "rect": next_button_rect()})
	return out


# --- actions ---------------------------------------------------------------------

## What a tap on target `name` does (ChoiceWidget calls this; tests call it
## directly). dialog_remove is a hold: see hold_remove().
func tap(name: String) -> void:
	if refused:
		return
	if name != "field":
		_stop_typing()
	if name.begins_with("tile_"):
		var i := name.substr(5).to_int()
		if i >= 0 and i < Profiles.PICTURES.size():
			picture = Profiles.PICTURES[i]
			_beep_tone()
	else:
		match name:
			"back", "nav_back":
				_go_back()
			"next":
				_go_next()
			"field":
				_start_typing()
			"save":
				if mode == Mode.EDIT:
					_beep(true)
					_refresh()
					saved.emit(profile_id, Profiles.clean_name(name_text), picture)
					return
			"remove":
				if can_remove():
					dialog_open = true
					hold_t = -1.0
			"dialog_back":
				dialog_open = false
				hold_t = -1.0
	_refresh()


## Types into the name box (the LineEdit calls this; tests too). The box
## never holds more than Profiles.NAME_MAX letters.
func set_name_text(s: String) -> void:
	name_text = s.left(Profiles.NAME_MAX)
	if line != null and line.text != name_text:
		line.text = name_text
		line.caret_column = name_text.length()
	queue_redraw()


## Advances the Remove hold by `dt` seconds; at HOLD_S it emits removed().
## Returns true when that happened.
func hold_remove(dt: float) -> bool:
	if not dialog_open or not can_remove():
		return false
	hold_t = maxf(hold_t, 0.0) + dt
	queue_redraw()
	if hold_t >= HOLD_S:
		hold_t = -1.0
		dialog_open = false
		_beep(true)
		removed.emit(profile_id)
		return true
	return false


func release_hold() -> void:
	if hold_t >= 0.0:
		hold_t = -1.0
		queue_redraw()


func _go_back() -> void:
	if mode == Mode.EDIT or step == Step.PICK:
		if first_run:
			return
		back.emit()
		return
	step = (step - 1) as Step


func _go_next() -> void:
	if mode == Mode.EDIT:
		return
	if step == Step.CONFIRM:
		_beep(true)
		_refresh()
		created.emit(Profiles.clean_name(name_text), picture)
		return
	step = (step + 1) as Step
	if step == Step.NAME and is_inside_tree():
		_start_typing.call_deferred()


# --- scene -----------------------------------------------------------------------

func _ready() -> void:
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	choice.picked.connect(_on_picked)
	line = M3.line_edit(NAME_FIELD, Profiles.NAME_MAX)
	line.visible = false
	line.select_all_on_focus = true
	line.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	line.text_changed.connect(set_name_text)
	line.text_submitted.connect(func(_t: String) -> void:
		_stop_typing()
		if mode == Mode.CREATE and step == Step.NAME:
			_go_next()
		_refresh())
	line.focus_exited.connect(_stop_typing)
	add_child(line)
	if refused:
		back.emit.call_deferred()
		return
	_refresh()


func _refresh() -> void:
	queue_redraw()
	_speak_step()
	if choice == null:
		return
	_live = []
	var rects := []
	for t in targets():
		if t["name"] == "dialog_remove":
			continue  # held, see _unhandled_input
		_live.append(t["name"])
		rects.append(t["rect"])
	if rects.is_empty():
		choice.close()
	else:
		choice.present(rects, 0)


## The step's prompt, once each time the step opens.
func _speak_step() -> void:
	if not voice or mode != Mode.CREATE or step == _spoken or refused:
		return
	var ell := EllwynnRef.here(self)
	if ell == null:
		return
	_spoken = step
	match step:
		Step.PICK:
			ell.prompt("K3")
		Step.NAME:
			ell.prompt("K4")
		_:
			ell.clear_prompt()


func _on_picked(i: int) -> void:
	if i >= 0 and i < _live.size():
		tap(str(_live[i]))
	else:
		_refresh()


func _start_typing() -> void:
	if line == null:
		return
	var tr := M3.field_text_rect(field_rect())
	line.position = tr.position
	line.size = tr.size
	line.text = name_text
	line.visible = true
	line.grab_focus()
	queue_redraw()


func _stop_typing() -> void:
	if line == null or not line.visible:
		return
	name_text = line.text.left(Profiles.NAME_MAX)
	line.visible = false
	if line.has_focus():
		line.release_focus()
	queue_redraw()


func _typing() -> bool:
	return line != null and line.visible


## The dialog's Remove is held, not tapped (like Reset).
func _unhandled_input(event: InputEvent) -> void:
	if voice and not dialog_open and Pointer.is_press(event) \
			and WhoScreen.title_rect(_shows_top_back()).has_point(Pointer.local_pos(self, event)):
		# a tap on the title says the step's prompt again
		var ell := EllwynnRef.here(self)
		if ell != null and ell.replay_prompt():
			get_viewport().set_input_as_handled()
		return
	if not dialog_open or not can_remove():
		return
	if not (Pointer.is_press(event) or Pointer.is_release(event) or Pointer.is_drag(event)):
		return
	var r: Rect2 = dialog_rects()[1]
	var p := Pointer.local_pos(self, event)
	if Pointer.is_press(event):
		if r.grow(ChoiceWidget.PAD).has_point(p):
			get_viewport().set_input_as_handled()
			hold_t = 0.0
	elif hold_t >= 0.0 and (Pointer.is_release(event) or not r.grow(30).has_point(p)):
		release_hold()


func _process(delta: float) -> void:
	if hold_t >= 0.0 and hold_remove(delta):
		_refresh()


func _beep(good: bool) -> void:
	var b := get_node_or_null("/root/Beeper") if is_inside_tree() else null
	if b != null:
		if good:
			b.good()
		else:
			b.bad()


func _beep_tone() -> void:
	var b := get_node_or_null("/root/Beeper") if is_inside_tree() else null
	if b != null:
		b.tone(660.0, 0.06)


# --- drawing ---------------------------------------------------------------------

func _state(name: String) -> M3.State:
	return M3.State.PRESSED if name == pressed else M3.State.NORMAL


func _title() -> String:
	if mode == Mode.EDIT:
		return "Edit"
	match step:
		Step.NAME:
			return "Name"
		Step.CONFIRM:
			return "Yes?"
	return "Pick"


func _draw() -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), M3.SURFACE)
	M3.top_bar(self, _title(), _shows_top_back() and not refused, _state("back"))
	if refused:
		return
	if mode == Mode.EDIT:
		_draw_edit()
	else:
		match step:
			Step.PICK:
				_draw_tiles(PICK_TILE_Y)
				_draw_full(Vector2(480, NAV_Y - 8.0))
			Step.NAME:
				M3.card(self, NAME_HEAD)
				_draw_head(Profiles.PICTURES.find(picture), NAME_HEAD)
				_draw_field(NAME_FIELD)
			Step.CONFIRM:
				M3.card(self, CONFIRM_CARD)
				_draw_full(Vector2(CONFIRM_CARD.get_center().x, CONFIRM_CARD.end.y - 24.0))
				var shown := Profiles.clean_name(name_text)
				if shown.is_empty():
					shown = Profiles.default_name(roster)
				M3.text_center(self, Rect2(M3.SAFE.position.x, CONFIRM_CARD.end.y + 16.0, M3.SAFE.size.x, 72.0),
						shown, M3.DISPLAY, M3.ON_SURFACE)
		if _shows_top_back():
			M3.button(self, back_button_rect(), "Back", M3.Style.TEXT, M3.Icon.NONE, _state("nav_back"))
		var last := step == Step.CONFIRM
		M3.button(self, next_button_rect(), "Yes" if last else "Next", M3.Style.FILLED,
				M3.Icon.CHECK if last else M3.Icon.NONE, _state("next"))
	if dialog_open:
		_draw_dialog()


func _draw_edit() -> void:
	var rr := remove_action_rect()
	if can_remove():
		M3.button(self, rr, "Remove", M3.Style.TONAL, M3.Icon.BIN, _state("remove"))
	else:
		M3.button(self, rr, "Remove", M3.Style.TONAL, M3.Icon.BIN, M3.State.DISABLED)
	_draw_field(EDIT_FIELD)
	M3.button(self, save_button_rect(), "Save", M3.Style.FILLED, M3.Icon.CHECK, _state("save"))
	_draw_tiles(EDIT_TILE_Y)


func _draw_field(r: Rect2) -> void:
	var typing := _typing()
	var value: String = line.text if typing else name_text
	M3.text_field(self, r, "Name", value, Profiles.NAME_MAX, typing)
	if not typing and value.is_empty():
		M3.text_left(self, M3.field_text_rect(r), Profiles.default_name(roster), M3.TITLE,
				Color(M3.ON_SURFACE_VARIANT, 0.5))


func _draw_tiles(top: float) -> void:
	for i in Profiles.PICTURES.size():
		var r := tile_rect(i, top)
		var chosen: bool = Profiles.PICTURES[i] == picture
		M3.card(self, r, false, _state("tile_%d" % i))
		_draw_head(i, r)
		if chosen:
			# the ring and check go over the picture
			RoundBox.frame(self, r.grow(-2.0), M3.GOLD, 4.0, M3.SHAPE_M - 2.0)
			M3.check_badge(self, Vector2(r.end.x - 18.0, r.position.y + 18.0))


## The top of picture `i` inside tile `r`, at 1:1.
func _draw_head(i: int, r: Rect2) -> void:
	if i < 0:
		return
	var tex := Look.hero_texture(str(Profiles.PICTURES[i]))
	if tex == null:
		return
	var ts := Vector2(tex.get_width(), tex.get_height())
	var size := Vector2(minf(CROP.x, ts.x), minf(CROP.y, ts.y))
	var src := Rect2(Vector2(roundf((ts.x - size.x) / 2.0), 0.0), size)
	var at := (r.get_center() - size / 2.0).round()
	draw_texture_rect_region(tex, Rect2(at, size), src)


## The whole chosen picture standing on `feet` (its bottom middle), at 1:1.
func _draw_full(feet: Vector2) -> void:
	var tex := Look.hero_texture(picture)
	if tex == null:
		return
	var ts := Vector2(tex.get_width(), tex.get_height())
	draw_texture(tex, (feet - Vector2(ts.x / 2.0, ts.y)).round())


func _draw_dialog() -> void:
	var title := "Remove %s?" % Profiles.clean_name(name_text)
	var rs := M3.dialog(self, title, _dialog_body(), DIALOG_LABELS, true, M3.Icon.BIN)
	if hold_t >= 0.0:
		var r: Rect2 = rs[1]
		var k := clampf(hold_t / HOLD_S, 0.0, 1.0)
		var bar := Rect2(r.position + Vector2(16, r.size.y - 12), Vector2(roundf((r.size.x - 32) * k), 6))
		draw_rect(bar, M3.ON_ERROR_CONTAINER)
