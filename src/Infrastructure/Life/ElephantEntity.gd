# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive colossal Elephant.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ElephantEntity.gd
# ==============================================================================
class_name ElephantEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/elephant.glb"


func _init(spawn_pos: Vector3) -> void:
	# Elephants spawn with 10 Hearts of health (20 HP) due to their colossal size
	super(spawn_pos, 20)
	name = "Entity_ELEPHANT"


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calculated via GLB Analyzer V5
	strategy.scale_multiplier = Vector3(3.0012, 3.0012, 3.0012)
	strategy.position_offset = Vector3(0.0, 1.7500, 0.0)
	strategy.rotation_offset = Vector3(0, 90, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(3.30, 3.50, 4.00)
	strategy.collision_position = Vector3(0.0, 1.575, 0.0)
	
	# Animations paths
	strategy.anim_idle_name = "idle"
	strategy.anim_walk_name = "walk"
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_collision_box_size() -> Vector3:
	return Vector3(3.30, 3.50, 4.00)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 1.575, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds/elephants)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Elephant panic escape velocity (slightly lower jump due to high body mass)
	velocity.y = JUMP_VELOCITY * 0.75
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
