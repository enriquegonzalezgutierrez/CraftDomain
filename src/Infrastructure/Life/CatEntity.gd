# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive domestic Cat.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# PROPERTY ASSIGNMENT CORRECTION:
#              - Corrected the property names from '.anim_idle_path' to '.anim_idle_name' 
#                and '.anim_walk_name' to prevent GLB asset-loading compiler failures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CatEntity.gd
# ==============================================================================
class_name CatEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/cat.glb"


func _init(spawn_pos: Vector3) -> void:
	# Cats spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_CAT"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calculated via GLB Analyzer V5
	strategy.scale_multiplier = Vector3(1.0, 1.0, 1.0)
	strategy.position_offset = Vector3(0.0, 0.0, 0.0)
	strategy.rotation_offset = Vector3(0, 180, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(0.2, 0.36, 0.5)
	strategy.collision_position = Vector3(0.0, 0.18, 0.0)
	
	# Animations paths corrected from '_path' to '_name' for GLB compliance
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
