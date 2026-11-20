extends Node
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

@export_category("Main Settings")
@export var ui_click: AudioStream
@export var ui_hover: AudioStream
@export var ui_cancel: AudioStream

## Gameplay sound effects are loaded by name from res://sfx/:
##   sfx_<name>.wav|ogg|mp3            one sound
##   sfx_<name>_1.ogg, sfx_<name>_2.ogg  variations, one is picked at random
## To change a sound, replace/add files with those names. Missing files are
## skipped silently, so the game never breaks because of audio.
## Sources and licenses of the current files: res://sfx/CREDITS.md
const SFX_DIR := "res://sfx/"
const SFX_EXTENSIONS := ["wav", "ogg", "mp3"]
const MAX_VARIATIONS := 8
const SFX_EVENTS := [
	"placement", "ghost_attack", "enemy_flee", "enemy_run", "core_hit",
	"wave_start", "wave_clear", "victory", "game_over",
	"ability_pocong", "ability_kuntilanak", "ability_tuyul",
	"lamp", "whisper", "dukun_stun",
]
## Per-event tuning: volume (dB), random pitch spread, minimum gap between
## plays (s) and max overlapping copies. Frequent sounds are kept quiet and
## throttled so a big wave doesn't turn into noise.
const SFX_SETTINGS := {
	"ghost_attack": {"volume": -12.0, "pitch_spread": 0.12, "min_gap": 0.07, "max_voices": 4},
	"enemy_flee": {"volume": -5.0, "pitch_spread": 0.15, "min_gap": 0.08, "max_voices": 3},
	# Footsteps running off, layered after the gasp; few voices so crowds stay readable
	"enemy_run": {"volume": -9.0, "pitch_spread": 0.08, "min_gap": 0.35, "max_voices": 2},
	"core_hit": {"volume": -2.0, "pitch_spread": 0.05, "min_gap": 0.1, "max_voices": 3},
	"placement": {"volume": -2.0, "pitch_spread": 0.08},
	"lamp": {"volume": -4.0},
	"whisper": {"volume": -1.0, "pitch_spread": 0.06},
	"wave_start": {"volume": -3.0},
	"victory": {"volume": -2.0},
	"game_over": {"volume": -2.0},
	"dukun_stun": {"volume": -4.0, "min_gap": 0.3},
}

var _sfx_streams: Dictionary = {}
var _last_played_ms: Dictionary = {}
var _voices: Dictionary = {}

func _ready() -> void:
	# Keep playing while the tree is paused (guide, victory, game over)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Safety net: restart the music even if a track was imported without looping
	bgm_player.finished.connect(bgm_player.play)
	for event in SFX_EVENTS:
		var variations: Array[AudioStream] = []
		for ext in SFX_EXTENSIONS:
			var single: String = "%ssfx_%s.%s" % [SFX_DIR, event, ext]
			if ResourceLoader.exists(single):
				variations.append(load(single))
			for i in range(1, MAX_VARIATIONS + 1):
				var numbered: String = "%ssfx_%s_%d.%s" % [SFX_DIR, event, i, ext]
				if ResourceLoader.exists(numbered):
					variations.append(load(numbered))
		if not variations.is_empty():
			_sfx_streams[event] = variations

func play_bgm(stream: AudioStream) -> void:
	# Don't restart the track when returning to a menu that plays the same music
	if bgm_player.stream == stream and bgm_player.playing:
		return
	bgm_player.stream = stream
	bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "SFX"
	sfx_player.stream = stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
	return sfx_player

## Plays a named gameplay sound (see SFX_EVENTS). `pitch` lets callers give
## each ghost its own voice with the same sample.
func play_event(event: String, pitch: float = 1.0) -> void:
	var variations: Array = _sfx_streams.get(event, [])
	if variations.is_empty():
		return
	var settings: Dictionary = SFX_SETTINGS.get(event, {})
	var now := Time.get_ticks_msec()
	var min_gap_ms := int(float(settings.get("min_gap", 0.0)) * 1000.0)
	if now - int(_last_played_ms.get(event, -100000)) < min_gap_ms:
		return
	var voices: int = _voices.get(event, 0)
	if voices >= int(settings.get("max_voices", 8)):
		return
	_last_played_ms[event] = now
	var spread := float(settings.get("pitch_spread", 0.0))
	var volume := float(settings.get("volume", 0.0))
	var burst := int(settings.get("burst", 1))
	var gap := float(settings.get("burst_gap", 0.0))
	var pool := variations.duplicate()
	pool.shuffle()
	for i in burst:
		if i > 0:
			await get_tree().create_timer(gap, true).timeout
		var stream: AudioStream = pool[i % pool.size()]
		var final_pitch := pitch * randf_range(1.0 - spread, 1.0 + spread)
		var player := play_sfx(stream, volume, final_pitch)
		_voices[event] = int(_voices.get(event, 0)) + 1
		player.finished.connect(func(): _voices[event] = maxi(int(_voices.get(event, 1)) - 1, 0))

func playsfx_click() -> void:
	play_sfx(ui_click)

func playsfx_hover() -> void:
	play_sfx(ui_hover)

func playsfx_cancel() -> void:
	play_sfx(ui_cancel)
