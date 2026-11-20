extends TextureButton

@export var ghost_scene: PackedScene
@export var ghost_group: Node2D
@export var ghost_type: String = ""  # e.g. "pocong", "kuntilanak", "tuyul"

func _ready() -> void:
	button_down.connect(_on_pressed)
	# Hover card with stats + skill so players know what they're buying
	tooltip_text = GuideData.ghost_tooltip(ghost_type.to_lower())
	# Light up placement spots while hovering, so players know where to drop
	mouse_entered.connect(_set_spot_preview.bind(true))
	mouse_exited.connect(_set_spot_preview.bind(false))

func _set_spot_preview(enabled: bool) -> void:
	for hints in get_tree().get_nodes_in_group("placement_hints"):
		hints.preview_requested = enabled

func _make_custom_tooltip(for_text: String) -> Object:
	return GuideData.make_tooltip(for_text)

func _on_pressed() -> void:
	if ghost_group == null or ghost_scene == null:
		return
	var new_ghost = ghost_scene.instantiate()
	ghost_group.add_child(new_ghost)
	new_ghost.global_position = get_global_mouse_position()
	new_ghost.dragging = true
	new_ghost.drag_offset = Vector2.ZERO
