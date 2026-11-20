extends CanvasLayer
class_name HelpPanel

## In-game player guide. Visual language is borrowed from the existing HUD:
## red brush strips (Start Wave), Scream Again headings, the stone/blood
## level-select button, blue spirit-flame energy icon.
##
## - "?" stone button opens a full-screen guide with 4 pages; game pauses.
## - Opens automatically on the very first play.
## - Short popups introduce each enemy type the first time it appears.

const TITLE_FONT := preload("res://fonts/Scream Again.ttf")
const BODY_FONT := preload("res://fonts/Cinzel-Bold.ttf")
const BRUSH_TEX := preload("res://ui/top_hud/asset/Wave_Progression_Background.png")
const STONE_TEX := preload("res://ui/level_select/button.png")
const ENERGY_TEX := preload("res://ui/top_hud/asset/Energy_Terror.png")
const FEAR_TEX := preload("res://enemies/Enemy_Fear.png")
const CORE_TEX := preload("res://core/asset/Player_Core_HP.png")
const LAMP_TEX := preload("res://interactables/assets/Button_Lampu-base.png")
const WHISPER_TEX := preload("res://interactables/assets/Button_Bisikan-base.png")

const WHITE := Color(0.95, 0.94, 0.92)
const MUTED := Color(0.62, 0.62, 0.62)
const BLOOD := Color(0.82, 0.2, 0.25)
const SPIRIT := Color(0.62, 0.85, 1.0)

const HELP_BUTTON_SIZE := 54.0
const HELP_BUTTON_CENTER_FROM_RIGHT := 55.0  # centre of the dark side strip (x 1810-1920)
const HELP_BUTTON_CENTER_Y := 50.0
const TOAST_SECONDS := 6.0

const BRUSH_TAIL := 30.0
const BRUSH_PAD_TOP := 6.0
const BRUSH_PAD_BOTTOM := 16.0
const TAB_PAD := 30.0

const PAGES := ["Cara Main", "Hantu", "Pengunjung", "Ruangan"]

var _overlay: Control
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _help_button: TextureButton
var _toast_box: VBoxContainer
var _paused_before_open: bool = false
var _installed_theme: Theme

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_tooltip_theme()
	_build_help_button()
	_build_toast_area()
	_build_overlay()

	if not GameManager.has_seen_guide():
		GameManager.mark_guide_seen()
		open_guide.call_deferred(0)
	else:
		show_toast("Siap-siap", "Seret hantu ke lingkaran roh, lalu tekan Start Wave.  ? = panduan", null)

func _exit_tree() -> void:
	# Remove the tooltip theme we put on the root window (only if it's still ours)
	if _installed_theme and get_tree().root.theme == _installed_theme:
		get_tree().root.theme = null

# Fade popups while a ghost is being dragged so they never hide placement spots
func _process(delta: float) -> void:
	var dragging := false
	for node in get_tree().get_nodes_in_group("ghost"):
		if node is GhostBase and (node as GhostBase).dragging:
			dragging = true
			break
	_toast_box.modulate.a = move_toward(_toast_box.modulate.a, 0.1 if dragging else 1.0, delta * 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close_guide()
		get_viewport().set_input_as_handled()

# ── Public API ────
func is_open() -> bool:
	return _overlay != null and _overlay.visible

func open_guide(page: int = 0) -> void:
	if is_open():
		return
	_paused_before_open = get_tree().paused
	get_tree().paused = true
	_select_page(page)
	_toast_box.hide()
	_overlay.show()
	_overlay.modulate.a = 0.0
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.18)
	_help_button.hide()
	AudioManager.playsfx_click()

func close_guide() -> void:
	if not is_open():
		return
	_overlay.hide()
	_toast_box.show()
	_help_button.show()
	get_tree().paused = _paused_before_open
	AudioManager.playsfx_cancel()

func announce_enemy(enemy_type: int) -> void:
	var stats := GuideData.enemy_stats(enemy_type)
	var body := "%s\nLawan: %s" % [GuideData.enemy_trait(enemy_type), GuideData.enemy_counter(enemy_type)]
	show_toast(GuideData.enemy_name(enemy_type) + " datang", body, stats.get("texture"))

func show_toast(title: String, body: String, icon: Texture2D) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.82)
	style.border_color = BLOOD
	style.border_width_left = 5
	style.content_margin_left = 20
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	if icon:
		row.add_child(_texture(icon, Vector2(64, 64)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(_heading(title.to_upper(), 30, WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(_body(body, 17, Color(0.82, 0.82, 0.82), 470.0, HORIZONTAL_ALIGNMENT_LEFT))

	_toast_box.add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)

# ── Building blocks ────
func _heading(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _body(text: String, size: int, color: Color, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	if width > 0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 2)
	return label

func _texture(tex: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect

func _brush_style(pad: float = 34.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = BRUSH_TEX
	style.texture_margin_left = 12
	style.texture_margin_right = 40
	# The right end of the brush is a slanted tail, so give it extra room;
	# Scream Again glyphs sit low in their line box, so pad the bottom more.
	style.content_margin_left = pad
	style.content_margin_right = pad + BRUSH_TAIL
	style.content_margin_top = BRUSH_PAD_TOP
	style.content_margin_bottom = BRUSH_PAD_BOTTOM
	return style

func _plain_tab_style() -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	# Same box as the active brush tab so labels don't jump when switching
	empty.content_margin_left = TAB_PAD
	empty.content_margin_right = TAB_PAD + BRUSH_TAIL
	empty.content_margin_top = BRUSH_PAD_TOP
	empty.content_margin_bottom = BRUSH_PAD_BOTTOM
	return empty

func _energy_row(amount: Variant, size: int = 24) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(_texture(ENERGY_TEX, Vector2(size + 4, size + 4)))
	row.add_child(_heading(str(amount), size + 4, SPIRIT))
	return row

func _stat(caption: String, value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.add_child(_heading(value, 26, WHITE))
	box.add_child(_body(caption, 13, MUTED, 0))
	return box

func _stat_row(stats: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	for pair in stats:
		row.add_child(_stat(pair[0], pair[1]))
	return row

func _divider(width: float) -> Control:
	var line := ColorRect.new()
	line.color = Color(BLOOD, 0.55)
	line.custom_minimum_size = Vector2(width, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return line

func _column(width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 10)
	return col

func _columns(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	return row

# ── UI construction ────
func _install_tooltip_theme() -> void:
	var root := get_tree().root
	if root.theme != null:
		return # someone else owns the root theme; leave it alone
	var theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.03, 0.03, 0.94)
	panel.border_color = BLOOD
	panel.border_width_left = 4
	panel.set_content_margin_all(14)
	panel.content_margin_left = 18
	theme.set_stylebox("panel", "TooltipPanel", panel)
	theme.set_font("font", "TooltipLabel", BODY_FONT)
	theme.set_font_size("font_size", "TooltipLabel", 17)
	theme.set_color("font_color", "TooltipLabel", Color(0.88, 0.88, 0.88))
	root.theme = theme
	_installed_theme = theme

func _build_help_button() -> void:
	_help_button = TextureButton.new()
	_help_button.texture_normal = STONE_TEX
	_help_button.ignore_texture_size = true
	_help_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_help_button.custom_minimum_size = Vector2(HELP_BUTTON_SIZE, HELP_BUTTON_SIZE)
	_help_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help_button.position = Vector2(-HELP_BUTTON_CENTER_FROM_RIGHT - HELP_BUTTON_SIZE / 2.0, HELP_BUTTON_CENTER_Y - HELP_BUTTON_SIZE / 2.0)
	_help_button.size = _help_button.custom_minimum_size
	_help_button.pivot_offset = _help_button.size / 2.0
	_help_button.tooltip_text = "Panduan bermain"
	add_child(_help_button)

	var mark := _heading("?", 26, WHITE)
	mark.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	mark.add_theme_constant_override("outline_size", 6)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.offset_top = -3 # the brush font sits low; nudge it to the visual centre
	mark.offset_bottom = -3
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_button.add_child(mark)

	_help_button.pressed.connect(open_guide.bind(0))
	_help_button.mouse_entered.connect(func():
		AudioManager.playsfx_hover()
		_help_button.create_tween().tween_property(_help_button, "scale", Vector2.ONE * 1.12, 0.12))
	_help_button.mouse_exited.connect(func():
		_help_button.create_tween().tween_property(_help_button, "scale", Vector2.ONE, 0.12))

func _build_toast_area() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.position.y = 96
	_toast_box.add_theme_constant_override("separation", 10)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.01, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	_overlay.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	# Title on a red brush strip, like the Start Wave banner
	var title_holder := PanelContainer.new()
	title_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_holder.add_theme_stylebox_override("panel", _brush_style(60))
	title_holder.add_child(_heading("PANDUAN", 46, WHITE))
	col.add_child(title_holder)

	# Page tabs: plain words, the active one sits on a brush strip
	var tabs := _columns(4)
	col.add_child(tabs)
	for i in PAGES.size():
		var button := Button.new()
		button.text = PAGES[i].to_upper()
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", TITLE_FONT)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_color_override("font_hover_color", WHITE)
		button.add_theme_color_override("font_pressed_color", WHITE)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func():
			AudioManager.playsfx_click()
			_select_page(i))
		button.mouse_entered.connect(AudioManager.playsfx_hover)
		tabs.add_child(button)
		_tab_buttons.append(button)

	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(page_area)
	for page in [_page_how_to_play(), _page_ghosts(), _page_enemies(), _page_rooms()]:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.add_child(page)
		page_area.add_child(center)
		_pages.append(center)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	col.add_child(footer)
	var close := Button.new()
	close.text = "MAIN!"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_override("font", TITLE_FONT)
	close.add_theme_font_size_override("font_size", 34)
	close.add_theme_color_override("font_color", WHITE)
	close.add_theme_color_override("font_hover_color", WHITE)
	close.add_theme_color_override("font_pressed_color", WHITE)
	for state in ["normal", "hover", "pressed"]:
		close.add_theme_stylebox_override(state, _brush_style(56))
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(close_guide)
	close.mouse_entered.connect(func():
		AudioManager.playsfx_hover()
		close.pivot_offset = close.size / 2.0
		close.create_tween().tween_property(close, "scale", Vector2.ONE * 1.06, 0.1))
	close.mouse_exited.connect(func():
		close.create_tween().tween_property(close, "scale", Vector2.ONE, 0.1))
	footer.add_child(close)
	footer.add_child(_body("Esc untuk menutup  ·  buka lagi lewat tombol ? di kanan atas", 14, MUTED, 0))

func _select_page(index: int) -> void:
	index = clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		var active := i == index
		_pages[i].visible = active
		for state in ["normal", "hover", "pressed"]:
			_tab_buttons[i].add_theme_stylebox_override(state, _brush_style(TAB_PAD) if active else _plain_tab_style())
		_tab_buttons[i].add_theme_color_override("font_color", WHITE if active else MUTED)

# ── Pages ────
func _page_how_to_play() -> Control:
	var page := _column(1560)
	page.add_theme_constant_override("separation", 40)
	var row := _columns(40)
	page.add_child(row)

	var wave_banner := PanelContainer.new()
	wave_banner.add_theme_stylebox_override("panel", _brush_style(26))
	wave_banner.add_child(_heading("START WAVE", 24, WHITE))

	var steps := [
		["1", "Taruh hantu", _texture(GuideData.ghost_icon("pocong"), Vector2(120, 120)),
			"Seret ikon hantu dari kanan bawah ke lingkaran roh yang menyala."],
		["2", "Mulai wave", wave_banner,
			"Tekan Start Wave di kiri atas kalau sudah siap."],
		["3", "Takut-takuti", _texture(GuideData.crop_to_content(FEAR_TEX), Vector2(100, 100)),
			"Hantu menyerang sendiri. Pengunjung yang ketakutan kabur & memberi energi."],
		["4", "Jaga inti", _texture(GuideData.crop_to_content(CORE_TEX), Vector2(100, 100)),
			"Pengunjung yang lolos mengurangi HP Inti Situs. Habis berarti kalah."],
	]
	for step in steps:
		var col := _column(340)
		col.add_child(_heading(step[0], 56, BLOOD))
		var visual_holder := CenterContainer.new()
		visual_holder.custom_minimum_size = Vector2(0, 124)
		visual_holder.add_child(step[2])
		col.add_child(visual_holder)
		col.add_child(_heading(step[1].to_upper(), 28, WHITE))
		col.add_child(_body(step[3], 18, Color(0.8, 0.8, 0.8), 320))
		row.add_child(col)

	var legend := _columns(48)
	page.add_child(legend)
	var energy := _columns(10)
	energy.add_child(_texture(ENERGY_TEX, Vector2(30, 30)))
	energy.add_child(_body("Energi dipakai untuk hantu & jebakan ruangan", 16, MUTED, 0))
	legend.add_child(energy)
	legend.add_child(_body("Hantu kemerahan = diperkuat Lampu", 16, Color(1.0, 0.55, 0.55), 0))
	legend.add_child(_body("Hantu kebiruan = dibekukan Dukun", 16, Color(0.6, 0.65, 1.0), 0))
	return page

func _page_ghosts() -> Control:
	var page := _column(1500)
	page.add_theme_constant_override("separation", 22)
	var row := _columns(70)
	page.add_child(row)
	for ghost_id in GuideData.GHOST_ORDER:
		var s := GuideData.ghost_stats(ghost_id)
		var col := _column(420)
		col.add_theme_constant_override("separation", 8)
		var head := _columns(16)
		head.add_child(_texture(GuideData.ghost_icon(ghost_id), Vector2(96, 96)))
		var name_box := VBoxContainer.new()
		name_box.alignment = BoxContainer.ALIGNMENT_CENTER
		name_box.add_theme_constant_override("separation", -6)
		name_box.add_child(_heading(GuideData.ghost_name(ghost_id).to_upper(), 38, WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		var cost := _energy_row(s.get("cost", "?"), 20)
		cost.alignment = BoxContainer.ALIGNMENT_BEGIN
		name_box.add_child(cost)
		head.add_child(name_box)
		col.add_child(head)
		col.add_child(_body(GuideData.ghost_role(ghost_id), 17, MUTED, 400))
		if not s.is_empty():
			col.add_child(_stat_row([
				["damage", GuideData.num(s.damage)],
				["detik / serang", GuideData.num(s.rate)],
				["jangkauan", GuideData.num(s.range)],
			]))
		col.add_child(_divider(240))
		col.add_child(_heading(GuideData.ability_name(ghost_id).to_upper(), 26, BLOOD))
		col.add_child(_body(GuideData.ability_short(ghost_id), 18, Color(0.85, 0.85, 0.85), 400))
		col.add_child(_body(GuideData.ability_cooldown_text(ghost_id), 14, MUTED, 400))
		row.add_child(col)
	page.add_child(_body("Tombol skill ada di atas ikon hantu. Hantu yang sudah ditaruh bisa diseret ulang dengan biaya kecil.", 15, MUTED, 0))
	return page

func _page_enemies() -> Control:
	var row := _columns(70)
	for enemy_type in range(GuideData.ENEMY_SCENES.size()):
		var s := GuideData.enemy_stats(enemy_type)
		var col := _column(420)
		if s.get("texture"):
			col.add_child(_texture(s.texture, Vector2(130, 130)))
		col.add_child(_heading(GuideData.enemy_name(enemy_type).to_upper(), 38, WHITE))
		if not s.is_empty():
			col.add_child(_stat_row([
				["rasa takut", str(s.fear)],
				["kecepatan", GuideData.num(s.speed)],
				["energi", "+" + str(s.energy)],
			]))
		col.add_child(_divider(240))
		col.add_child(_body(GuideData.enemy_trait(enemy_type), 18, Color(0.85, 0.85, 0.85), 400))
		col.add_child(_body("Lawan: " + GuideData.enemy_counter(enemy_type), 16, SPIRIT, 400))
		row.add_child(col)
	return row

func _page_rooms() -> Control:
	var v := GuideData.room_values()
	var page := _column(1300)
	page.add_theme_constant_override("separation", 30)
	var row := _columns(120)
	page.add_child(row)
	# Same labels as the buttons on the map, so players recognise them
	var rooms := [
		[LAMP_TEX, "LAMP", "Matikan lampu", v.lamp_cost, GuideData.lamp_text(), v.lamp_cd],
		[WHISPER_TEX, "WHISPER", "Bisikan", v.whisper_cost, GuideData.whisper_text(), v.whisper_cd],
	]
	for room in rooms:
		var col := _column(460)
		# Brush art + label stacked, same as the RoomInteraction buttons
		var brush := GuideData.crop_to_content(room[0])
		var banner := Control.new()
		banner.custom_minimum_size = Vector2(300, 300.0 * brush.get_height() / brush.get_width())
		banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var art := _texture(brush, Vector2.ZERO)
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		banner.add_child(art)
		var label := _heading(room[1], 32, WHITE)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.add_child(label)
		col.add_child(banner)
		col.add_child(_body(room[2], 18, MUTED, 0))
		col.add_child(_energy_row(room[3]))
		col.add_child(_body(room[4], 18, Color(0.85, 0.85, 0.85), 420))
		col.add_child(_body("Isi ulang %s dtk" % GuideData.num(room[5]), 14, MUTED, 420))
		row.add_child(col)
	page.add_child(_body("Tombol jebakan ada di peta. Klik saat pengunjung lewat ruangannya. Vlogger hanya kena setengahnya.", 15, MUTED, 0))
	return page
