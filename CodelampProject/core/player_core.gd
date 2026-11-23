extends Area2D
signal core_destroyed 

var max_hp: int = 10
var current_hp: int

# Reference to the UI Label
@onready var hp_label: Label = $HPLabel

func _ready() -> void:
	current_hp = max_hp 
	
	# Display initial HP (e.g., "10/10")
	_update_hp_display()
	
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if "core_damage" in body:
			current_hp -= body.core_damage
		else:
			current_hp -= 10 
		
		# Ensure HP doesn't go below 0
		if current_hp < 0:
			current_hp = 0
			
		# Update UI Label
		_update_hp_display()
		AudioManager.play_event("core_hit")
		Vfx.screen_shake(10.0, 0.3)
		Vfx.screen_flash()
		Vfx.hit_burst(global_position, Vfx.BLOOD, 2.2)
		Vfx.float_text(global_position, "-%d" % (body.core_damage if "core_damage" in body else 10), Vfx.BLOOD, 34)
			
		print("Core damaged! Current HP: ", current_hp)
		
		body.queue_free()
		
		if current_hp <= 0:
			trigger_game_over()

func _update_hp_display() -> void:
	if hp_label:
		# Format: "HP: 10/10"
		hp_label.text = str(current_hp) + "/" + str(max_hp)
			
func trigger_game_over() -> void:
	current_hp = 0
	_update_hp_display()
	print("GAME OVER TER-TRIGGER!") 
	emit_signal("core_destroyed")
