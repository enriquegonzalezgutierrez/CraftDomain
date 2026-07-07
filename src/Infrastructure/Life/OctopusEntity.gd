# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive marine Octopus.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# HABITAT-DRIVEN SPAWNING (DDD Compliance):
#              - Overrides `_get_habitat()` to return AQUATIC, ensuring it 
#                spawns strictly submerged in deep water.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/OctopusEntity.gd
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/octopus.glb"


func _init(spawn_pos: Vector3) -> void:
	# Octopuses spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_OCTOPUS"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

func _get_habitat() -> MobRegistry.Habitat:
	return MobRegistry.Habitat.AQUATIC


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calibrated for the Octopus GLB Mesh
	strategy.scale_multiplier = Vector3(1.8525, 1.8525, 1.8525)
	strategy.position_offset = Vector3(0.0, 0.3156, 0.0)
	strategy.rotation_offset = Vector3(0, 90, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(1.0, 0.75, 1.1)
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

## Override: Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow smooth swimming glide)
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true
