# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive Pig.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# ROTATION CALIBRATION (LSP Fix):
#              - Corrected 'rotation_offset' from Y=-90 to Y=90 to rotate the visual 
#                mesh exactly 180 degrees, ensuring the pig faces and walks forward!
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PigEntity.gd
# ==============================================================================
class_name PigEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/pig.glb"


func _init(spawn_pos: Vector3) -> void:
	# Pigs spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_PIG"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calculated via GLB Analyzer V5
	strategy.scale_multiplier = Vector3(9.4485, 9.4485, 9.4485)
	strategy.position_offset = Vector3(0.0, 0.0102, 0.0)
	strategy.rotation_offset = Vector3(0, 90, 0) # Corrected Y-rotation so the pig faces forward
	
	# Physical collision dimensions (0.75m height)
	strategy.collision_size = Vector3(0.6, 0.75, 0.65)
	strategy.collision_position = Vector3(0.0, 0.375, 0.0)
	
	# Baked built-in animation track names inside pig.glb
	strategy.anim_idle_name = "idle"
	strategy.anim_walk_name = "walk"
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# COMBAT & LOOT LOGIC
# ==============================================================================

## Override: Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
