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
	
	# Animations paths
	strategy.anim_idle_path = "" # Baked inside single .glb
	strategy.anim_walk_path = ""
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.2, 0.36, 0.5)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.18, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Cat panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
