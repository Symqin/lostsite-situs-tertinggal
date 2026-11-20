extends Node2D
class_name PlacementHints

## Shows where ghosts can be placed, styled as faint "spirit circles"
## (same cold blue as the Energi Teror flame).
## - Visible while a ghost is dragged or a ghost button is hovered.
## - Spots near the cursor are brighter; far ones stay faint, so 17 spots
##   don't turn the map into a debug overlay.
## - Dragged ghosts snap onto the nearest free spot (see find_snap).
## - Spots already holding a ghost are not drawn at all.

const SPIRIT := Color(0.62, 0.85, 1.0)
const VISUAL_RADIUS := 30.0
const SNAP_DISTANCE := 75.0
const OCCUPIED_DISTANCE := 40.0
const DASHES := 10

## Set by ghost buttons while hovered, so players see spots before dragging.
var preview_requested: bool = false

var _time: float = 0.0
var _visibility: float = 0.0  # 0..1 fade for the whole overlay

func _ready() -> void:
	add_to_group("placement_hints")
	z_index = 5

func _process(delta: float) -> void:
	var active := preview_requested or _get_dragging_ghost() != null
	_visibility = move_toward(_visibility, 1.0 if active else 0.0, delta * 5.0)
	_time += delta
	if _visibility > 0.0:
		queue_redraw()
	elif active == false and _visibility == 0.0:
		queue_redraw()

func _draw() -> void:
	if _visibility <= 0.0:
		return
	var dragged := _get_dragging_ghost()
	var focus: Vector2 = dragged.global_position if dragged else get_global_mouse_position()
	var breathe := 0.5 + 0.5 * sin(_time * 3.0)

	for spot in _get_spots():
		if _is_taken(spot.position, dragged):
			continue
		var pos: Vector2 = to_local(spot.position)
		var radius: float = maxf(spot.radius, VISUAL_RADIUS)
		var is_target := dragged != null and dragged.global_position.distance_to(spot.position) < 1.0
		# Nearby spots are bright, distant ones faint
		var near := 1.0 - clampf(focus.distance_to(spot.position) / 900.0, 0.0, 1.0)
		var strength := (0.35 + 0.65 * near) * _visibility
		if is_target:
			strength = _visibility
		_draw_spirit_circle(pos, radius, strength, breathe, is_target)

func _draw_spirit_circle(pos: Vector2, radius: float, strength: float, breathe: float, is_target: bool) -> void:
	var fill_alpha := (0.10 if is_target else 0.05 + 0.03 * breathe) * strength
	draw_circle(pos, radius, Color(SPIRIT, fill_alpha))
	draw_arc(pos, radius, 0.0, TAU, 48, Color(SPIRIT, (0.95 if is_target else 0.55) * strength), 2.5 if is_target else 1.5, true)
	# Slowly turning dashed outer ring, like the core's ritual circle
	var outer := radius + (9.0 if is_target else 6.0)
	var spin := _time * (1.2 if is_target else 0.4)
	var dash := TAU / DASHES
	for i in DASHES:
		var a := spin + i * dash
		draw_arc(pos, outer, a, a + dash * 0.45, 6, Color(SPIRIT, (0.8 if is_target else 0.3) * strength), 1.5, true)

# ── Queries ────
## Returns the nearest free spot within SNAP_DISTANCE of `point`, or {}.
func find_snap(point: Vector2, ignore: GhostBase) -> Dictionary:
	var best := {}
	var best_distance := SNAP_DISTANCE
	for spot in _get_spots():
		var distance := point.distance_to(spot.position)
		if distance < best_distance and not _is_taken(spot.position, ignore):
			best = spot
			best_distance = distance
	return best

func _get_dragging_ghost() -> GhostBase:
	for node in get_tree().get_nodes_in_group("ghost"):
		if node is GhostBase and (node as GhostBase).dragging:
			return node
	return null

func _get_spots() -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	for area in get_tree().get_nodes_in_group("placement_area"):
		if not area is Area2D:
			continue
		var shape_node := (area as Node).get_node_or_null("CollisionShape2D") as CollisionShape2D
		var pos: Vector2 = (area as Area2D).global_position
		var radius := 24.0
		if shape_node:
			pos = shape_node.global_position
			if shape_node.shape is CircleShape2D:
				radius = (shape_node.shape as CircleShape2D).radius * absf(shape_node.global_scale.x)
		spots.append({"position": pos, "radius": radius})
	return spots

func _is_taken(spot_pos: Vector2, ignore: GhostBase) -> bool:
	for node in get_tree().get_nodes_in_group("ghost"):
		if node == ignore or not node is GhostBase:
			continue
		var ghost := node as GhostBase
		if ghost.is_placed and not ghost.dragging and ghost.global_position.distance_to(spot_pos) <= OCCUPIED_DISTANCE:
			return true
	return false
