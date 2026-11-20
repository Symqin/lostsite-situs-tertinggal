extends Area2D
class_name GhostBase

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var id: String
@export var fear_damage: float #Ghost base damage (never modified at runtime, see get_effective_damage)
@export var attack_rate: float #Time between attacks
@export var cost: int
@export var cost_upgrade: int
@export var cost_move: int
@export var attack_range: float = 180.0
@onready var placement_area_detector: Area2D = $PlacementAreaDetector

const RANGE_COLOR := Color(0.62, 0.85, 1.0) # spirit blue, matches PlacementHints

var dragging : bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2
var last_valid_position: Vector2
var disable_timer: float = 0.0 # ghost stun

# Some booleans to check whether ghost can be placed
var can_place: bool = false
var in_placement_area: bool = false
var overlapping_ghost: bool = false
var is_placed: bool = false
var attack_cooldown: float = 0.0
var ability_name: String = ""
var ability_start_cooldown: float = 0.0
var ability_cooldown: float = 0.0
var ability_duration: float = 0.0
var ability_current_cooldown: float = 0.0
var _ability_has_been_used: bool = false

# Damage modifiers. Stacked separately so buffs from different sources
# (room lamp, Tuyul steal) can expire independently without clobbering each other.
var _damage_multipliers: Array[float] = []
var _flat_damage_bonus: float = 0.0
var is_buffed: bool:
	get: return not _damage_multipliers.is_empty()

var _hovered: bool = false

func _ready():
	add_to_group("ghost")
	#Set original position
	original_position = global_position
	last_valid_position = global_position
	placement_area_detector.area_entered.connect(_on_area_entered)
	placement_area_detector.area_exited.connect(_on_area_exited)
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())

func _process(delta: float) -> void:
	#Move position with mouse if dragging
	if dragging:
		z_index = 1
		var desired := get_global_mouse_position() + drag_offset
		# Snap onto the nearest free placement spot so dropping is forgiving
		var hints := get_tree().get_first_node_in_group("placement_hints") as PlacementHints
		var snap := hints.find_snap(desired, self) if hints else {}
		global_position = snap.position if not snap.is_empty() else desired
		_refresh_can_place()
		# Placeable: normal look. Not placeable: faded, slightly red "ghost of a ghost"
		modulate = Color.WHITE if can_place else Color(1.0, 0.6, 0.6, 0.55)
		queue_redraw()
		if Input.is_action_just_released("click"):
			dragging = false
			place_ghost()
			queue_redraw()
		return
	z_index = 0

	if is_placed:
		if ability_current_cooldown > 0.0:
			ability_current_cooldown = max(ability_current_cooldown - delta, 0.0)
		# --- COLOR PRIORITY & STUN SYSTEM ---
		if disable_timer > 0.0:
			disable_timer -= delta
			modulate = Color(0.5, 0.5, 1.0) # Pale Blue (Stunned)
			return # Skip attack logic
		if is_buffed:
			modulate = Color(1.0, 0.5, 0.5) # Red (Room Buff)
		else:
			modulate = Color.WHITE # Normal

		# --- ATTACK & TRACKING SYSTEM ---
		if attack_cooldown > 0.0:
			attack_cooldown -= delta

		var target := _find_target_in_range()

		if target:
			#Rotate
			look_at(target.global_position)
			rotation_degrees -= 90
			#attack
			if attack_cooldown <= 0.0:
				target.take_fear_damage(roundi(get_effective_damage()), id)
				attack_cooldown = attack_rate
				_play_attack_animation()
		else:
			# No target found, stop attack animation and return to idley
			if anim_sprite.animation == "attack" and anim_sprite.is_playing():
				anim_sprite.stop()
				anim_sprite.play("idle")

# Attack range preview: shown when the dragged ghost sits on a valid spot,
# or when hovering a placed ghost. Thin outline only, so the map stays readable.
func _draw() -> void:
	var show_range := (dragging and can_place) or (_hovered and is_placed and not dragging)
	if not show_range:
		return
	var radius := attack_range / maxf(absf(global_scale.x), 0.001)
	draw_circle(Vector2.ZERO, radius, Color(RANGE_COLOR, 0.06))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(RANGE_COLOR, 0.45), 1.5, true)

# Allow ghost to be dragged again after placing
func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# Start Dragging
	if not viewport.is_input_handled() and event.is_action_pressed("click"):
		dragging = true
		drag_offset = global_position - get_global_mouse_position()
		rotation = 0.0

#Tries to place ghost
func place_ghost() -> void:
	_refresh_can_place()
	if !can_place:
		if is_placed:
			global_position = last_valid_position
		else:
			queue_free()
		return
	var main_node := get_tree().current_scene
	if not is_placed:
		if main_node and main_node.has_method("try_spend_terror_energy"):
			if not main_node.try_spend_terror_energy(cost):
				queue_free()
				return
	elif global_position.distance_to(last_valid_position) > 1.0:
		# Moving an already placed ghost costs cost_move.
		if main_node and main_node.has_method("try_spend_terror_energy"):
			if not main_node.try_spend_terror_energy(cost_move):
				global_position = last_valid_position
				return
	is_placed = true
	anim_sprite.play("idle")
	last_valid_position = global_position
	attack_cooldown = 0.0

func _find_target_in_range() -> EnemyBase:
	var nearest: EnemyBase = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is EnemyBase:
			var enemy := node as EnemyBase
			if enemy.is_fleeing:
				continue
			var distance := global_position.distance_to(enemy.global_position)
			if distance <= attack_range and distance < nearest_distance:
				nearest = enemy
				nearest_distance = distance
	return nearest

# Recomputes placement validity from what the detector currently overlaps,
# so several ghosts entering/leaving can't leave stale flags behind.
func _refresh_can_place() -> void:
	in_placement_area = false
	overlapping_ghost = false
	for area in placement_area_detector.get_overlapping_areas():
		if area == self:
			continue
		if area.is_in_group("placement_area"):
			in_placement_area = true
		elif area is GhostBase and (area as GhostBase).is_placed:
			overlapping_ghost = true
	can_place = in_placement_area and not overlapping_ghost

func _on_area_entered(_area: Area2D) -> void:
	_refresh_can_place()

func _on_area_exited(_area: Area2D) -> void:
	_refresh_can_place()

# stun effect to the ghost for a specific duration
func apply_disable(duration: float) -> void:
	disable_timer = duration

func can_activate_ability() -> bool:
	if not is_placed:
		return false
	return ability_current_cooldown <= 0.0

func try_activate_ability() -> bool:
	if not can_activate_ability():
		return false
	var activated := _activate_ability()
	if not activated:
		return false
	if _ability_has_been_used:
		ability_current_cooldown = ability_cooldown
	else:
		ability_current_cooldown = ability_start_cooldown
		_ability_has_been_used = true
	return true

func get_ability_cooldown_left() -> float:
	return max(ability_current_cooldown, 0.0)

func _activate_ability() -> bool:
	return false

func _play_attack_animation() -> void: #inherit attack animation masing2 hantu
	pass

func _on_attack_animation_finished() -> void: #inherit stop animasi saat musuh defeated
	pass

# ── Damage modifiers ────
func get_effective_damage() -> float:
	var multiplier := 1.0
	for m in _damage_multipliers:
		multiplier = maxf(multiplier, m) # strongest active multiplier wins, no stacking
	return fear_damage * multiplier + _flat_damage_bonus

# FUNCTION TO RECEIVE BUFF FROM ROOM INTERACTION
func apply_damage_buff(multiplier: float, duration: float) -> void:
	_damage_multipliers.append(multiplier)
	await get_tree().create_timer(duration).timeout
	_damage_multipliers.erase(multiplier)

# Flat bonus (e.g. Tuyul's Steal). Caller is responsible for removing it.
func add_damage_bonus(amount: float) -> void:
	_flat_damage_bonus += amount

func remove_damage_bonus(amount: float) -> void:
	_flat_damage_bonus = maxf(_flat_damage_bonus - amount, 0.0)
