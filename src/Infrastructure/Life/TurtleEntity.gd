# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing an aquatic Sea Turtle.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# HABITAT-DRIVEN SPAWNING (DDD Compliance):
#              - Overrides `_get_habitat()` to return AMPHIBIOUS. This allows turtles 
#                to spawn safely both in water and sandy shores without getting stuck.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/TurtleEntity.gd
# ==============================================================================
class_name TurtleEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/turtle.glb"


func _init(spawn_pos: Vector3) -> void:
	# Turtles spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_TURTLE"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

func _get_habitat() -> MobRegistry.Habitat:
	return MobRegistry.Habitat.AMPHIBIOUS


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calibrated for the Turtle GLB Mesh
	strategy.scale_multiplier = Vector3(0.0570, 0.0570, 0.0570)
	strategy.position_offset = Vector3(0.0, 0.0, 0.0)
	strategy.rotation_offset = Vector3(0, 180, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(0.30, 0.35, 0.65)
	strategy.collision_position = Vector3(0.0, 0.175, 0.0)
	
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


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow smooth gliding)
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true
