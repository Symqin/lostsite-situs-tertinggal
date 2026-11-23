extends RefCounted
class_name Vfx

## Lightweight combat juice, all drawn in code (no extra art needed):
## spirit-orb projectiles, hit sparks, shockwave rings, floating numbers,
## sprite hit-flash and screen shake. Everything spawns into the "VfxLayer"
## node of the current scene and frees itself when done.

const TEXT_FONT := preload("res://fonts/Scream Again.ttf")
const FLASH_SHADER := preload("res://vfx/hit_flash.gdshader")

# Palette shared with the HUD/guide
const SPIRIT := Color(0.62, 0.85, 1.0)
const BLOOD := Color(0.9, 0.2, 0.28)
const GOLD := Color(1.0, 0.8, 0.3)
const PALE := Color(0.9, 0.95, 1.0)
const ROOM := Color(0.75, 0.55, 1.0)

## Colour of everything a damage source produces (orb, sparks, numbers)
static func color_for(source: String) -> Color:
	match source:
		"pocong", "Haunted Stomp": return PALE
		"kuntilanak", "Dreadful Scream": return BLOOD
		"tuyul", "Steal": return GOLD
		"room": return ROOM
	return SPIRIT

static func _layer() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var layer := tree.current_scene.get_node_or_null("VfxLayer")
	return layer if layer else tree.current_scene

static func _spawn(node: Node2D, at: Vector2) -> Node2D:
	var layer := _layer()
	if layer == null:
		node.free()
		return null
	layer.add_child(node)
	node.global_position = at
	return node

# ── Public helpers ────
## Glowing orb that flies from `from` to `target` and calls `on_hit` on arrival.
static func projectile(from: Vector2, target: Node2D, color: Color, on_hit: Callable) -> void:
	var orb := Projectile.new()
	orb.target = target
	orb.color = color
	orb.on_hit = on_hit
	_spawn(orb, from)

## Small spark burst + ring, used on every hit.
static func hit_burst(at: Vector2, color: Color, size: float = 1.0) -> void:
	var b := Burst.new()
	b.color = color
	b.radius = 26.0 * size
	b.sparks = int(7 * size) + 2
	b.duration = 0.32
	_spawn(b, at)

## Expanding ring showing an ability's area.
static func shockwave(at: Vector2, radius: float, color: Color, delay: float = 0.0, width: float = 5.0) -> void:
	var r := Ring.new()
	r.color = color
	r.max_radius = radius
	r.width = width
	r.delay = delay
	_spawn(r, at)

## Floating text (damage numbers, "!", "+15").
static func float_text(at: Vector2, text: String, color: Color, size: int = 26, rise: float = 46.0) -> void:
	var t := FloatText.new()
	t.text = text
	t.color = color
	t.font_size = size
	t.rise = rise
	_spawn(t, at)

## White blink on a sprite (adds the flash material the first time).
static func flash(sprite: CanvasItem, color: Color = Color.WHITE, duration: float = 0.14) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		sprite.material = mat
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 0.85)
	var tween := sprite.create_tween()
	tween.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 0.85, 0.0, duration)

## Quick squash-and-stretch "punch" on a sprite.
static func punch(sprite: Node2D, base_scale: Vector2, amount: float = 0.18) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", base_scale * (1.0 + amount), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Small jitter of a sprite's offset (hit reaction).
static func jitter(sprite: AnimatedSprite2D, strength: float = 4.0) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tween := sprite.create_tween()
	for i in 4:
		tween.tween_property(sprite, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength / maxf(sprite.scale.x, 0.01), 0.03)
	tween.tween_property(sprite, "offset", Vector2.ZERO, 0.04)

## Shakes the whole world (HUD layers are CanvasLayers and stay still).
static func screen_shake(strength: float = 10.0, duration: float = 0.3) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.current_scene as Node2D if tree else null
	if world == null:
		return
	var tween := world.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		tween.tween_property(world, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, 0.03)
	tween.tween_property(world, "position", Vector2.ZERO, 0.03)

## Red edge flash over the whole screen.
static func screen_flash(color: Color = Color(0.8, 0.0, 0.05, 0.35), duration: float = 0.35) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 40
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	tree.current_scene.add_child(layer)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, duration)
	tween.tween_callback(layer.queue_free)


# ── Effect nodes ────
class Projectile extends Node2D:
	var target: Node2D
	var color: Color
	var on_hit: Callable
	var speed := 850.0
	var _trail: PackedVector2Array = []
	var _last_target_pos: Vector2
	var _done := false

	func _ready() -> void:
		z_index = 20
		if is_instance_valid(target):
			_last_target_pos = target.global_position

	func _process(delta: float) -> void:
		if _done:
			# Let the trail shrink away after impact
			if _trail.size() > 0:
				_trail.remove_at(0)
				queue_redraw()
			else:
				queue_free()
			return
		if is_instance_valid(target):
			_last_target_pos = target.global_position
		var to := _last_target_pos - global_position
		var step := speed * delta
		_trail.append(global_position)
		if _trail.size() > 12:
			_trail.remove_at(0)
		if to.length() <= step:
			global_position = _last_target_pos
			_done = true
			if is_instance_valid(target) and on_hit.is_valid():
				on_hit.call()
		else:
			global_position += to.normalized() * step
		queue_redraw()

	func _draw() -> void:
		var n := _trail.size()
		for i in n:
			var p := to_local(_trail[i])
			var k := float(i + 1) / (n + 1)
			draw_circle(p, 4.0 + 9.0 * k, Color(color, 0.08 + 0.35 * k))
		if not _done:
			draw_circle(Vector2.ZERO, 22.0, Color(color, 0.15))
			draw_circle(Vector2.ZERO, 13.0, Color(color, 0.5))
			draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 0.95))


class Burst extends Node2D:
	var color: Color
	var radius := 26.0
	var sparks := 8
	var duration := 0.32
	var _t := 0.0
	var _dirs: Array[Vector2] = []

	func _ready() -> void:
		z_index = 21
		for i in sparks:
			var a := TAU * i / sparks + randf_range(-0.3, 0.3)
			_dirs.append(Vector2.from_angle(a) * randf_range(0.6, 1.0))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var eased := 1.0 - pow(1.0 - k, 3.0)
		var fade := 1.0 - k
		draw_arc(Vector2.ZERO, radius * (0.4 + 0.8 * eased), 0.0, TAU, 32, Color(color, 0.7 * fade), 3.0 * fade + 1.0, true)
		if k < 0.25:
			draw_circle(Vector2.ZERO, radius * 0.55 * (1.0 - k * 4.0), Color(1, 1, 1, 0.8))
		for d in _dirs:
			var p0 := d * radius * (0.3 + 1.2 * eased)
			var p1 := d * radius * (0.1 + 0.9 * eased)
			draw_line(p1, p0, Color(color, fade), 2.5, true)


class Ring extends Node2D:
	var color: Color
	var max_radius := 200.0
	var width := 5.0
	var delay := 0.0
	var duration := 0.5
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		if _t >= delay + duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < delay:
			return
		var k := (_t - delay) / duration
		var r := max_radius * (1.0 - pow(1.0 - k, 3.0))
		var fade := 1.0 - k
		draw_circle(Vector2.ZERO, r, Color(color, 0.10 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(color, 0.85 * fade), width * (0.4 + fade), true)


class FloatText extends Node2D:
	var text := ""
	var color := Color.WHITE
	var font_size := 26
	var rise := 46.0
	var duration := 0.7
	var _t := 0.0
	var _drift := 0.0

	func _ready() -> void:
		z_index = 30
		_drift = randf_range(-14.0, 14.0)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - k * 6.0)  # quick scale-up at spawn
		var fade := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var size := int(font_size * pop)
		var w := Vfx.TEXT_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := Vector2(-w / 2.0 + _drift * k, -rise * (1.0 - pow(1.0 - k, 2.0)) - 20.0)
		draw_string_outline(Vfx.TEXT_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.05, 0.02, 0.02, fade))
		draw_string(Vfx.TEXT_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, fade))
