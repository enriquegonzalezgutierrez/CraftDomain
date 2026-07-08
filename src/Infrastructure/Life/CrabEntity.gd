# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the amphibious Beach Crab, designed to be
#              attached to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively physical
#                movement loops, crawling angles, and life-signals, delegating
#                visual and collision parameters to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity
#                and satisfies the base contracts without code-based instantiation.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CrabEntity.gd
# ==============================================================================
class_name CrabEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Crabs spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_CRAB"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	# Aligns nameplate correctly above the visual model
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# CIRCULAR SHIELD: Return int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
# This perfectly complies with LSP overrides and stops circular import compilation deadlocks.
# ==============================================================================
func _get_habitat() -> int:
	return 1 # Equivalent to MobRegistry.Habitat.AMPHIBIOUS


func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken (acting as crab meat)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
