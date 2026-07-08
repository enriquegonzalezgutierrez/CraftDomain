# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive Sheep. Delegating its visual
#              clay-voxel representation and collision properties to its scene.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively physical
#                passive movement, panic bounces, and signal-bound loot drops.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SheepEntity.gd
# ==============================================================================
class_name SheepEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sheep spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_SHEEP"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()


## Bypasses old procedural box compiling
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


func _get_habitat() -> int:
	return 0 # 0 = Habitat.TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	# Item ID 5: Shrubbery Leaves (acting as soft wool)
	inv.add_item(5, 1)
	# Item ID 16: Fried Chicken (acting as raw meat)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
