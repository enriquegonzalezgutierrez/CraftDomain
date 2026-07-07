# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken/duck.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision and lifecycle contracts.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected `IEntityVisualRepresentation` strategy.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/chicken.glb"


func _init(spawn_pos: Vector3) -> void:
	# Chickens spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2) 
	name = "Entity_CHICKEN"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calibrated for the Chicken GLB Mesh
	strategy.scale_multiplier = Vector3(4.6922, 4.6922, 4.6922)
	strategy.position_offset = Vector3(0.0, 0.0, 0.0)
	strategy.rotation_offset = Vector3(0, 180, 0)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(0.46, 0.69, 0.46)
	strategy.collision_position = Vector3(0.0, 0.345, 0.0)
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# COMBAT & LOOT LOGIC
# ==============================================================================

## Override: Drops 1x Fried Chicken on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)


## Flag used by the animation ticker to configure bouncy avian walks
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true
