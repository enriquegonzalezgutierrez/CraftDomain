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


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calculated via GLB Analyzer V5
	strategy.scale_multiplier = Vector3(9.4485, 9.4485, 9.4485)
	strategy.position_offset = Vector3(0.0, 0.0102, 0.0)
	strategy.rotation_offset = Vector3(0, -90, 0) # Face forward (-Z)
	
	# Physical collision dimensions (0.75m height)
	strategy.collision_size = Vector3(0.6, 0.75, 0.65)
	strategy.collision_position = Vector3(0.0, 0.375, 0.0)
	
	# Baked built-in animation track names inside pig.glb
	strategy.anim_idle_name = "idle"
	strategy.anim_walk_name = "walk"
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.75, 0.65)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.375, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Pig panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
