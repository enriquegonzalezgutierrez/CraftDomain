# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive marine Crab.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# HABITAT-DRIVEN SPAWNING (DDD Compliance):
#              - Overrides `_get_habitat()` to return AMPHIBIOUS, enabling crabs to 
#                spawn on sandy shores and traverse both sand and water seamlessly.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CrabEntity.gd
# ==============================================================================
class_name CrabEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/crab.glb"


func _init(spawn_pos: Vector3) -> void:
	# Crabs spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_CRAB"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

func _get_habitat() -> MobRegistry.Habitat:
	return MobRegistry.Habitat.AMPHIBIOUS


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calibrated for the Crab GLB Mesh
	strategy.scale_multiplier = Vector3(0.3, 0.3, 0.3)
	strategy.position_offset = Vector3(0.0, 0.0, 0.0)
	strategy.rotation_offset = Vector3(0, 180, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(0.6, 0.75, 0.65)
	strategy.collision_position = Vector3(0.0, 0.375, 0.0)
	
	# Baked built-in animations
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


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds/crabs)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
