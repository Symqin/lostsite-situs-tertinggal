extends EnemyBase
class_name Dukun

const STUN_RANGE: float = 250.0
const STUN_DURATION: float = 2.0
const STUN_COOLDOWN: float = 20.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Test the inheritence (Remove later)
	name = "Dukun"
	super._ready()
	
	if sprite:
		sprite.play("walk")
	
	print("Fear: %s, Speed: %s, Terror: %s" % [max_fear_bar, speed, terror_energy])

# Cooldown timer for the active stun skill
var skill_cooldown_timer: float = 0.0

func _process(delta: float) -> void:
	if is_fleeing: 
		return 
		
	# Process the active skill cooldown
	if skill_cooldown_timer > 0:
		skill_cooldown_timer -= delta
	else:
		cast_disable_skill()

func take_fear_damage(amount: int, damage_source: String = "ghost") -> void:
	# Passive: Halve ALL incoming fear damage (from ghosts or rooms)
	amount = int(amount / 2.0)
	print(name, " passive triggered! Damage from ", damage_source, " halved to: ", amount)
	
	super.take_fear_damage(amount, damage_source)

# Active Skill: Area of Effect (AoE) Stun
func cast_disable_skill() -> void:
	var skill_range: float = STUN_RANGE
	var has_casted: bool = false
	
	# Scan for all ghosts currently placed on the map
	for node in get_tree().get_nodes_in_group("ghost"):
		if node.get("is_placed") == true:
			var distance = global_position.distance_to(node.global_position)
			
			if distance <= skill_range:
				if node.has_method("apply_disable"):
					node.apply_disable(STUN_DURATION)
					print(name, " casted a 2-second stun on: ", node.name)
					has_casted = true
				
	# Reset the cooldown if AT LEAST ONE ghost is successfully stunned
	if has_casted:
		Vfx.shockwave(global_position, skill_range, Color(0.55, 0.65, 1.0), 0.0, 5.0)
		AudioManager.play_event("dukun_stun")
		skill_cooldown_timer = STUN_COOLDOWN
	else:
		skill_cooldown_timer = 0.5
