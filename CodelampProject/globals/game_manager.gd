extends Node

@export var levels: Array[PackedScene]

var current_level_index: int = 0

func set_current_level_index(index: int) -> void:
	current_level_index = index

func get_level(level_index: int) -> PackedScene:
	if levels.is_empty():
		printerr("LevelManager: No levels assigned!")
		return null
	if level_index < 0 or level_index >= levels.size():
		printerr("LevelManager: Level index %d out of range!" % level_index)
		return null
	return levels[level_index]

func get_current_level() -> PackedScene:
	return get_level(current_level_index)

func get_next_level() -> PackedScene:
	if current_level_index + 1 >= levels.size():
		print("LevelManager: Already at last level.")
		return null
	current_level_index += 1
	return get_current_level()

func has_next_level() -> bool:
	return current_level_index + 1 < levels.size()

func is_last_level() -> bool:
	return current_level_index >= levels.size() - 1

func reset() -> void:
	current_level_index = 0

# ── Player Guide progress ────
# Stored in user:// so the full guide only auto-opens on the very first play.
const GUIDE_SAVE_PATH := "user://guide.cfg"
var _seen_enemy_types: Dictionary = {}

# Returns true the first time an enemy type is seen this session.
func mark_enemy_seen(enemy_type: int) -> bool:
	if _seen_enemy_types.has(enemy_type):
		return false
	_seen_enemy_types[enemy_type] = true
	return true

func has_seen_guide() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(GUIDE_SAVE_PATH) != OK:
		return false
	return bool(cfg.get_value("guide", "seen", false))

func mark_guide_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GUIDE_SAVE_PATH)
	cfg.set_value("guide", "seen", true)
	cfg.save(GUIDE_SAVE_PATH)
