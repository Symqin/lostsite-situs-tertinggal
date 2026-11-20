extends RefCounted
class_name GuideData

## Single source of player-facing guide content (guide panel, tooltips, popups).
## Numbers are read from ghost/enemy scenes and script constants, so the guide
## stays correct when the team rebalances the game. Keep sentences SHORT:
## players skim, they don't read paragraphs mid-game.

const GHOST_SCENES := {
	"pocong": "res://ghosts/pocong.tscn",
	"kuntilanak": "res://ghosts/kunilanak.tscn",
	"tuyul": "res://ghosts/tuyul.tscn",
}
const GHOST_ICONS := {
	"pocong": "res://ghosts/pocong_icon.png",
	"kuntilanak": "res://ghosts/kuntilanak_icon.png",
	"tuyul": "res://ghosts/tuyul_icon.png",
}
const GHOST_ORDER := ["pocong", "kuntilanak", "tuyul"]

# Index matches SpawnEntry.EnemyType
const ENEMY_SCENES := [
	"res://enemies/normal_enemy.tscn",
	"res://enemies/vlogger.tscn",
	"res://enemies/dukun.tscn",
]
const ENEMY_NAMES := ["Pengunjung", "Vlogger", "Dukun"]

# Palette taken from the game's own HUD (red brush strips, blue spirit flame)
const COLOR_BLOOD := "#d0343f"
const COLOR_SPIRIT := "#9fd8ff"
const COLOR_MUTED := "#9a9a9a"

static var _ghost_stats_cache: Dictionary = {}
static var _enemy_stats_cache: Dictionary = {}

static func num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))

# ── Stats read from scenes ────
static func ghost_stats(ghost_id: String) -> Dictionary:
	if _ghost_stats_cache.has(ghost_id):
		return _ghost_stats_cache[ghost_id]
	var stats := {}
	var scene: PackedScene = load(GHOST_SCENES.get(ghost_id, ""))
	if scene:
		var ghost := scene.instantiate() as GhostBase
		if ghost:
			stats = {
				"damage": ghost.fear_damage,
				"rate": ghost.attack_rate,
				"range": ghost.attack_range,
				"cost": ghost.cost,
				"cost_move": ghost.cost_move,
			}
			ghost.free()
	_ghost_stats_cache[ghost_id] = stats
	return stats

static func enemy_stats(enemy_type: int) -> Dictionary:
	if _enemy_stats_cache.has(enemy_type):
		return _enemy_stats_cache[enemy_type]
	var stats := {}
	if enemy_type >= 0 and enemy_type < ENEMY_SCENES.size():
		var scene: PackedScene = load(ENEMY_SCENES[enemy_type])
		if scene:
			var enemy := scene.instantiate() as EnemyBase
			if enemy:
				var texture: Texture2D = null
				var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
					texture = crop_to_content(sprite.sprite_frames.get_frame_texture("walk", 0))
				stats = {
					"fear": enemy.max_fear_bar,
					"speed": enemy.speed,
					"energy": enemy.terror_energy,
					"texture": texture,
				}
				enemy.free()
	_enemy_stats_cache[enemy_type] = stats
	return stats

## Trims transparent padding so small sprites can be shown at a readable size.
static func crop_to_content(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	return ImageTexture.create_from_image(image.get_region(used))

static func room_values() -> Dictionary:
	var room := RoomInteraction.new()
	var values := {
		"lamp_cost": room.cost_lampu, "lamp_cd": room.cooldown_lampu,
		"whisper_cost": room.cost_bisikan, "whisper_cd": room.cooldown_bisikan,
	}
	room.free()
	return values

# ── Ghosts ────
static func ghost_icon(ghost_id: String) -> Texture2D:
	return load(GHOST_ICONS.get(ghost_id, "")) as Texture2D

static func ghost_name(ghost_id: String) -> String:
	return ghost_id.capitalize()

static func ghost_role(ghost_id: String) -> String:
	match ghost_id:
		"pocong": return "Cepat & murah. Penjaga tikungan."
		"kuntilanak": return "Lambat, tapi sekali serang sangat menakutkan."
		"tuyul": return "Pendukung. Menguatkan hantu lain."
	return ""

static func ability_name(ghost_id: String) -> String:
	match ghost_id:
		"pocong": return "Haunted Stomp"
		"kuntilanak": return "Dreadful Scream"
		"tuyul": return "Steal"
	return ""

static func ability_short(ghost_id: String) -> String:
	match ghost_id:
		"pocong":
			return "Hentak %d pengunjung terdekat: +%s takut, terdorong mundur %d langkah." % [
				Pocong.STOMP_MAX_TARGETS, num(Pocong.STOMP_FEAR_DAMAGE), Pocong.STOMP_PUSH_STEPS]
		"kuntilanak":
			return "Semua pengunjung di sekitar: +%s takut & membeku %s detik." % [
				num(Kuntilanak.SCREAM_FEAR_DAMAGE), num(Kuntilanak.SCREAM_STUN_DURATION)]
		"tuyul":
			return "%s detik: hantu di sekitar +%s damage, pengunjung kabur memberi energi ekstra." % [
				num(Tuyul.STEAL_DURATION), num(Tuyul.STEAL_BONUS_DAMAGE)]
	return ""

static func ability_cooldowns(ghost_id: String) -> Vector2:
	match ghost_id:
		"pocong": return Vector2(Pocong.ABILITY_FIRST_COOLDOWN, Pocong.ABILITY_COOLDOWN)
		"kuntilanak": return Vector2(Kuntilanak.ABILITY_FIRST_COOLDOWN, Kuntilanak.ABILITY_COOLDOWN)
		"tuyul": return Vector2(Tuyul.ABILITY_FIRST_COOLDOWN, Tuyul.ABILITY_COOLDOWN)
	return Vector2.ZERO

static func ability_cooldown_text(ghost_id: String) -> String:
	var cd := ability_cooldowns(ghost_id)
	return "Isi ulang %s dtk, berikutnya %s dtk" % [num(cd.x), num(cd.y)]

static func ghost_tooltip(ghost_id: String) -> String:
	var s := ghost_stats(ghost_id)
	if s.is_empty():
		return ghost_name(ghost_id)
	return "[font_size=26][color=white]%s[/color][/font_size]   [color=%s]%s energi[/color]\n[color=%s]%s[/color]\n\n[color=%s]%s[/color]\n%s" % [
		ghost_name(ghost_id).to_upper(), COLOR_SPIRIT, s.cost,
		COLOR_MUTED, ghost_role(ghost_id),
		COLOR_BLOOD, ability_name(ghost_id).to_upper(), ability_short(ghost_id)]

static func ability_tooltip(ghost_id: String) -> String:
	return "[color=%s]%s[/color]\n%s\n[color=%s]%s. Butuh target di dekatnya.[/color]" % [
		COLOR_BLOOD, ability_name(ghost_id).to_upper(), ability_short(ghost_id),
		COLOR_MUTED, ability_cooldown_text(ghost_id)]

# ── Enemies ────
static func enemy_name(enemy_type: int) -> String:
	if enemy_type >= 0 and enemy_type < ENEMY_NAMES.size():
		return ENEMY_NAMES[enemy_type]
	return "Pengunjung"

static func enemy_trait(enemy_type: int) -> String:
	match enemy_type:
		SpawnEntry.EnemyType.NORMAL:
			return "Tidak punya kemampuan khusus."
		SpawnEntry.EnemyType.VLOGGER:
			return "Kebal setengah terhadap jebakan Ruangan."
		SpawnEntry.EnemyType.DUKUN:
			return "Menahan setengah rasa takut. Membekukan hantu di dekatnya %s detik." % num(Dukun.STUN_DURATION)
	return ""

static func enemy_counter(enemy_type: int) -> String:
	match enemy_type:
		SpawnEntry.EnemyType.NORMAL:
			return "Hantu apa pun cukup."
		SpawnEntry.EnemyType.VLOGGER:
			return "Andalkan serangan hantu."
		SpawnEntry.EnemyType.DUKUN:
			return "Sebar hantu, bekukan dengan Scream."
	return ""

# ── Rooms ────
static func lamp_text() -> String:
	return "Ruangan gelap %s detik. Hantu di dalamnya damage x%s." % [
		num(RoomInteraction.LAMP_DURATION), num(RoomInteraction.LAMP_DAMAGE_MULTIPLIER)]

static func whisper_text() -> String:
	return "Pengunjung di ruangan +%d takut & berhenti %s detik." % [
		RoomInteraction.WHISPER_FEAR_DAMAGE, num(RoomInteraction.WHISPER_STUN_DURATION)]

static func lamp_tooltip() -> String:
	var v := room_values()
	return "LAMP (matikan lampu) · %s energi\n%s\nIsi ulang %s dtk." % [v.lamp_cost, lamp_text(), num(v.lamp_cd)]

static func whisper_tooltip() -> String:
	var v := room_values()
	return "WHISPER (bisikan) · %s energi\n%s\nIsi ulang %s dtk." % [v.whisper_cost, whisper_text(), num(v.whisper_cd)]

# ── Tooltip control ────
static func make_tooltip(bbcode: String, width: float = 380.0) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_override("normal_font", HelpPanel.BODY_FONT)
	label.add_theme_font_size_override("normal_font_size", 17)
	label.add_theme_color_override("default_color", Color(0.88, 0.88, 0.88))
	label.add_theme_constant_override("line_separation", 3)
	label.text = bbcode
	return label
