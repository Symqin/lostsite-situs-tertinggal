extends CanvasLayer
class_name PauseMenu

## Pause button (stone circle under the "?" button) + pause overlay.
## - Click the button, press Esc or P to pause; the game also pauses itself
##   when the window loses focus.
## - Menu: Lanjutkan / Ulangi Level / Panduan / Menu Utama.
## - Disabled once the level is won or lost (those screens own the pause).
## Visual style matches HelpPanel (red brush strips, Scream Again).

const TITLE_SCENE := "res://ui/title_screen/tile_screen.tscn"
const BUTTON_GAP := 14.0  # vertical gap between the "?" and pause buttons

var _button: TextureButton
var _overlay: Control
var _help: HelpPanel

func _ready() -> void:
	layer = 45 # below the guide (50) so "Panduan" opens on top of this menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	_help = get_parent().get_node_or_null("HelpPanel") as HelpPanel
	_build_button()
	_build_overlay()

# The "?" button sits on a higher layer; hide it while this menu is up
# (the menu has its own "Panduan" entry).
func _process(_delta: float) -> void:
	if _help and _help._help_button:
		_help._help_button.visible = not is_open() and not _help.is_open()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pressed_p: bool = key != null and key.pressed and not key.echo and key.keycode == KEY_P
	var toggle: bool = event.is_action_pressed("ui_cancel") or pressed_p
	if not toggle:
		return
	if _help and _help.is_open():
		return # Esc closes the guide first
	if is_open():
		AudioManager.playsfx_cancel()
		resume()
	elif _can_pause():
		pause()
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# Pause automatically when the player alt-tabs away
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _can_pause() and not is_open():
		pause()

# ── Public API ────
func is_open() -> bool:
	return _overlay != null and _overlay.visible

func pause() -> void:
	if is_open() or not _can_pause():
		return
	get_tree().paused = true
	_overlay.show()
	_overlay.modulate.a = 0.0
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.15)
	_button.hide()
	AudioManager.playsfx_click()

func resume() -> void:
	if not is_open():
		return
	_overlay.hide()
	_button.show()
	get_tree().paused = false

# ── Internals ────
func _can_pause() -> bool:
	var main := get_parent()
	if main == null:
		return false
	if "_game_over" in main and main._game_over:
		return false
	var victory := main.get_node_or_null("VictoryUI") as CanvasItem
	if victory and victory.visible:
		return false
	if _help and _help.is_open():
		return false
	return true

func _brush_style(pad: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = HelpPanel.BRUSH_TEX
	style.texture_margin_left = 12
	style.texture_margin_right = 40
	style.content_margin_left = pad
	style.content_margin_right = pad + HelpPanel.BRUSH_TAIL
	style.content_margin_top = HelpPanel.BRUSH_PAD_TOP
	style.content_margin_bottom = HelpPanel.BRUSH_PAD_BOTTOM
	return style

func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HelpPanel.TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", HelpPanel.WHITE)
	return label

func _build_button() -> void:
	var size := HelpPanel.HELP_BUTTON_SIZE
	_button = TextureButton.new()
	_button.texture_normal = HelpPanel.STONE_TEX
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_button.custom_minimum_size = Vector2(size, size)
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Same column as the "?" button, one slot lower
	_button.position = Vector2(
		-HelpPanel.HELP_BUTTON_CENTER_FROM_RIGHT - size / 2.0,
		HelpPanel.HELP_BUTTON_CENTER_Y + size / 2.0 + BUTTON_GAP)
	_button.size = _button.custom_minimum_size
	_button.pivot_offset = _button.size / 2.0
	_button.tooltip_text = "Jeda (Esc / P)"
	add_child(_button)

	# Pause icon: two white bars with a dark edge, like the "?" glyph
	var icon := HBoxContainer.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.alignment = BoxContainer.ALIGNMENT_CENTER
	icon.add_theme_constant_override("separation", 5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var bar := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = HelpPanel.WHITE
		style.border_color = Color(0.1, 0.02, 0.02)
		style.set_border_width_all(2)
		style.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("panel", style)
		bar.custom_minimum_size = Vector2(8, 22)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(bar)
	_button.add_child(icon)

	_button.pressed.connect(pause)
	_button.mouse_entered.connect(func():
		AudioManager.playsfx_hover()
		_button.create_tween().tween_property(_button, "scale", Vector2.ONE * 1.12, 0.12))
	_button.mouse_exited.connect(func():
		_button.create_tween().tween_property(_button, "scale", Vector2.ONE, 0.12))

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.01, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)

	var title := PanelContainer.new()
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_stylebox_override("panel", _brush_style(60))
	title.add_child(_heading("JEDA", 56))
	col.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	_add_menu_button(col, "LANJUTKAN", resume, true)
	_add_menu_button(col, "ULANGI LEVEL", _restart)
	_add_menu_button(col, "PANDUAN", func():
		if _help:
			_help.open_guide(0))
	_add_menu_button(col, "MENU UTAMA", _to_title)

	var hint := Label.new()
	hint.text = "Esc / P untuk lanjut"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", HelpPanel.BODY_FONT)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", HelpPanel.MUTED)
	col.add_child(hint)

## Plain words; the hovered (or primary) entry sits on a red brush strip.
func _add_menu_button(parent: Control, text: String, action: Callable, primary := false) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", HelpPanel.TITLE_FONT)
	button.add_theme_font_size_override("font_size", 34)
	var idle_color := HelpPanel.WHITE if primary else HelpPanel.MUTED
	button.add_theme_color_override("font_color", idle_color)
	button.add_theme_color_override("font_hover_color", HelpPanel.WHITE)
	button.add_theme_color_override("font_pressed_color", HelpPanel.WHITE)
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 40
	plain.content_margin_right = 40 + HelpPanel.BRUSH_TAIL
	plain.content_margin_top = HelpPanel.BRUSH_PAD_TOP
	plain.content_margin_bottom = HelpPanel.BRUSH_PAD_BOTTOM
	button.add_theme_stylebox_override("normal", _brush_style(40) if primary else plain)
	button.add_theme_stylebox_override("hover", _brush_style(40))
	button.add_theme_stylebox_override("pressed", _brush_style(40))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(AudioManager.playsfx_hover)
	button.pressed.connect(func():
		AudioManager.playsfx_click()
		action.call())
	parent.add_child(button)

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
