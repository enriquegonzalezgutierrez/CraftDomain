# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: ElephantEntity
# Description: Physical character controller for the Colossal Elephant.
#              Delegates slow walk cycles, canyon limits, and stomp 
#              impacts to the decoupled ElephantAIBehavior strategy, managing
#              knockback immunities, dynamic player camera screen shake.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, heavy box colliders, local audio vocal timers, and ground-thud screen shake feedback.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name ElephantEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_CHAT_MIN_SEC: float = 25.0
const COOLDOWN_CHAT_MAX_SEC: float = 45.0

# Start with a random initial offset on spawn so they don't sync up
var _chat_timer: float = randf_range(8.0, 20.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Heavy elephant initialized with 10 Hearts of health (20 HP) and terrestrial boundaries
	super(spawn_pos, 20)
	entity_habitat = 0 # Terrestrial
	name = "Entity_ELEPHANT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target scans
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Elephant colossal AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ElephantAIBehavior.new()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_ELEPHANT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


## Symmetrical Heavy Stature: Elephants ignore standard physics recoil knockbacks!
func take_damage(amount: int, _knockback_force: Vector3, attacker: Node = null) -> void:
	# Passes Vector3.ZERO to base class, completely absorbing all push forces
	super(amount, Vector3.ZERO, attacker)


## Reactive callback triggered when the Domain Entity registers a successful hit.
func _on_domain_entity_took_damage(amount: int) -> void:
	super(amount)
	
	# Dampen the jump velocity afterward to enforce colossal mass
	velocity.y = JUMP_VELOCITY * 0.75


func _drop_loot(inv: IInventory) -> void:
	# Drops 2x Meat rations (ID 16) and 1x Stone Block (acting as tusk ivory, ID 1)
	inv.add_item(16, 2)
	inv.add_item(1, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL PRESENTATION & HEAVY STOMP SCREEN SHAKE
# ==============================================================================

## Step Stomp Impact: Evaluates player proximity and injects direct camera shake
## Note: Invoked via reflective calls by the ElephantAIBehavior strategy
func _play_heavy_step_impact() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var dist := global_position.distance_to(player_node.global_position)
			
			# If player is near (within 12 meters), trigger physical camera vibration
			if dist < 12.0:
				var intensity := remap(dist, 0.0, 12.0, 0.18, 0.02)
				player_node.set("_shake_intensity", intensity)
				
	# Play heavy stone footstep sound statically (Service Locator)
	AudioService.play_sfx_static("footstep_stone", global_position)


## Visual/Audio Elephant Trumpet: Plays the designated deep trumpet sound
func _play_elephant_chatter() -> void:
	AudioService.play_sfx_static("elephant_chatter", global_position, 75.0)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process ambient trumpet timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			_play_elephant_chatter()
