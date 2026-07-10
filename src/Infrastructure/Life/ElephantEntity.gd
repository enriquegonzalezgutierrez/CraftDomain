# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: ElephantEntity
# Description: Physical character controller for the Colossal Elephant.
#              Delegates slow walk cycles, canyon limits, and stomp 
#              impacts to the decoupled ElephantAIBehavior strategy, managing
#              knockback immunities and dynamic player camera screen shake.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, heavy box colliders, and ground-thud screen shake feedback.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, preserving base damage hooks while enforcing customized weight.
# - Dependency Inversion Principle (DIP): Injects the ElephantAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ElephantEntity.gd
# ==============================================================================
class_name ElephantEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Heavy elephant initialized with 10 Hearts of health (20 HP)
	super(spawn_pos, 20)
	name = "Entity_ELEPHANT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Elephant colossal AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ElephantAIBehavior.new()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

## Symmetrical Heavy Stature: Elephants ignore standard physics recoil knockbacks!
func take_damage(amount: int, _knockback_force: Vector3, attacker: Node = null) -> void:
	# Passes Vector3.ZERO to base class, completely absorbing all push forces
	super(amount, Vector3.ZERO, attacker)


## Reactive callback triggered when the Domain Entity registers a successful hit.
func _on_domain_entity_took_damage(amount: int) -> void:
	# 1. Restore the base class signal chains (Alert network and Karma systems)
	super(amount)
	
	# 2. Dampen the jump velocity afterward to enforce colossal mass
	velocity.y = JUMP_VELOCITY * 0.75


func _drop_loot(inv: IInventory) -> void:
	# Drops 2x Meat rations (ID 16) and 1x Stone Block (acting as ivory tusks, ID 1)
	inv.add_item(16, 2)
	inv.add_item(1, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL PRESENTATION & HEAVY PISOTÓN TEMBLOR DE PANTALLA
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
				# Remap distance to shake intensity [0.0 to 12.0m translates to 0.18 to 0.02 shake intensity]
				var intensity := remap(dist, 0.0, 12.0, 0.18, 0.02)
				player_node.set("_shake_intensity", intensity)
				
	# Play heavy stone footstep sound statically (Service Locator)
	AudioService.play_sfx_static("footstep_stone", global_position)
