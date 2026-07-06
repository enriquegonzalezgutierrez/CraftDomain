# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive flying tropical Parrot.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                and skeletal animations entirely to the FaunaVisualRepresentation strategy.
#              - Dependency Inversion Principle (DIP): Independent of physical rendering,
#                binding visuals purely to the IEntityVisualRepresentation abstraction.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ParrotEntity.gd
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/parrot.glb"

# Procedural flight animation variables
var _animation_time: float = 0.0
var _model_node: Node3D


func _init(spawn_pos: Vector3) -> void:
	# Parrots spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_PARROT"


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	strategy.scale_multiplier = Vector3(0.4350, 0.4350, 0.4350)
	
	# Dynamic Showcase Grounding:
	# Climbs up the ancestral tree to detect if we are inside the Showcase SubViewport.
	var is_showcase := false
	var current_node := get_parent()
	while current_node != null:
		if current_node is SubViewport and current_node.name != "root":
			is_showcase = true
			break
		current_node = current_node.get_parent()
	
	if is_showcase:
		# Anchor to ground level in showcase (Center offset: 0.402 * 0.4350 scale = 0.1750)
		strategy.position_offset = Vector3(0.0, 0.1750, 0.0)
	else:
		# Standard flight height in active gameplay
		strategy.position_offset = Vector3(0.0, 2.521, 0.0)
		
	# Rotations & Collision boundaries
	strategy.rotation_offset = Vector3(0, 90, 0)
	strategy.collision_size = Vector3(0.46, 0.69, 0.46)
	strategy.collision_position = Vector3(0.0, 0.345, 0.0)
	
	# Inject strategy into parent coordinator
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)
	
	# Retrieve the actual instanced model node reference to support flight bobs in _process()
	_model_node = visual_component.body_bob_node.get_child(0) as Node3D


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Real-time Procedural Flight Simulator Loop (OCP/SRP Compliant)
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		# Calculate speed vector (ignore vertical gravity velocity)
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		# 1. Thermal Hover Bobbing (Smooth vertical sine wave, slightly out-of-phase with the yellow bird!)
		var hover_bob := sin(_animation_time * 3.5) * 0.22
		
		# Determine if we are flying or grounded in the showcase
		var is_showcase := false
		var current_node := get_parent()
		while current_node != null:
			if current_node is SubViewport and current_node.name != "root":
				is_showcase = true
				break
			current_node = current_node.get_parent()
			
		if is_showcase:
			_model_node.position.y = 0.1750 # Frozen grounded
		else:
			_model_node.position.y = 2.521 + hover_bob
		
		# 2. Wing Flap Tilting and Forward Pitch
		if is_moving:
			# High-frequency roll rotation (Z-axis) simulating active flapping
			_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
			# Tilt forward (X-axis) when moving fast
			_model_node.rotation.x = deg_to_rad(12.0)
		else:
			# Slow resting breeze tilts
			_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
			_model_node.rotation.x = 0.0


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow flying)
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Avian panic bounce velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
