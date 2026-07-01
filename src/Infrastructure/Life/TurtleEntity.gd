# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive 
#              aquatic Sea Turtle. Floats, wanders, and glides across ocean bays.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/TurtleEntity.gd
# ==============================================================================
class_name TurtleEntity
extends PassiveEntity

# Paddle flipper joints for swimming animation
var _front_left_flipper: Node3D
var _front_right_flipper: Node3D
var _rear_left_flipper: Node3D
var _rear_right_flipper: Node3D


func _init(spawn_pos: Vector3) -> void:
	# Turtles spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_TURTLE"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var shell_color := Color(0.25, 0.18, 0.12)       # Dark brown shell core
	var shell_rim_color := Color(0.42, 0.65, 0.18)   # Forest green shell rim
	var skin_color := Color(0.35, 0.58, 0.22)        # Moss green skin
	var beak_yellow := Color(0.85, 0.72, 0.15)       # Yellow-green beak
	
	# 1. Main Shell Body (Attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.68, 0.22, 0.84), Vector3(0, 0.18, 0), shell_color) # Shell base
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.72, 0.06, 0.88), Vector3(0, 0.12, 0), shell_rim_color) # Rim
	
	# 2. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "TurtleHead"
	visual_component.head_node.position = Vector3(0, 0.18, -0.48)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.22, 0.18, 0.28), Vector3(0, 0, 0), skin_color) # Head core
	visual_component.create_box(visual_component.head_node, Vector3(0.18, 0.08, 0.10), Vector3(0, -0.05, -0.16), beak_yellow) # Beak
	
	# Small black eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.04, 0.04, 0.02), Vector3(-0.12, 0.04, -0.10), Color(0.12, 0.12, 0.15))
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.04, 0.04, 0.02), Vector3(0.12, 0.04, -0.10), Color(0.12, 0.12, 0.15))
	
	# 3. Front Flapping Flippers (Aletas, bobbing with the body)
	_front_left_flipper = Node3D.new()
	_front_left_flipper.name = "FrontLeftFlipper"
	_front_left_flipper.position = Vector3(-0.35, 0.12, -0.28)
	visual_component.body_bob_node.add_child(_front_left_flipper)
	visual_component.create_box(_front_left_flipper, Vector3(0.38, 0.04, 0.18), Vector3(-0.16, 0, 0), skin_color)
	
	_front_right_flipper = Node3D.new()
	_front_right_flipper.name = "FrontRightFlipper"
	_front_right_flipper.position = Vector3(0.35, 0.12, -0.28)
	visual_component.body_bob_node.add_child(_front_right_flipper)
	visual_component.create_box(_front_right_flipper, Vector3(0.38, 0.04, 0.18), Vector3(0.16, 0, 0), skin_color)
	
	# 4. Rear Steering Flippers
	_rear_left_flipper = Node3D.new()
	_rear_left_flipper.name = "RearLeftFlipper"
	_rear_left_flipper.position = Vector3(-0.30, 0.12, 0.35)
	visual_component.body_bob_node.add_child(_rear_left_flipper)
	visual_component.create_box(_rear_left_flipper, Vector3(0.22, 0.04, 0.15), Vector3(-0.08, 0, 0), skin_color)
	
	_rear_right_flipper = Node3D.new()
	_rear_right_flipper.name = "RearRightFlipper"
	_rear_right_flipper.position = Vector3(0.30, 0.12, 0.35)
	visual_component.body_bob_node.add_child(_rear_right_flipper)
	visual_component.create_box(_rear_right_flipper, Vector3(0.22, 0.04, 0.15), Vector3(0.08, 0, 0), skin_color)


## Overrides standard animations to execute a high-frequency flapping paddle loop when swimming.
func _process_procedural_animations(_delta: float) -> void:
	if not is_instance_valid(ai_component) or not is_instance_valid(visual_component):
		return
		
	var active_task := ai_component.current_task
	var is_moving := (active_task == NPCAIComponent.TaskState.WANDERING or 
						active_task == NPCAIComponent.TaskState.PANIC)
	
	# Front Flipper paddling animations (Using out-of-phase sine waves)
	if is_instance_valid(_front_left_flipper) and is_instance_valid(_front_right_flipper):
		if is_moving:
			var speed_mult := 8.0 if active_task == NPCAIComponent.TaskState.PANIC else 4.0
			_front_left_flipper.rotation.z = sin(visual_component._animation_time * speed_mult) * 0.45
			_front_right_flipper.rotation.z = -sin(visual_component._animation_time * speed_mult) * 0.45
			
			_rear_left_flipper.rotation.y = cos(visual_component._animation_time * speed_mult) * 0.25
			_rear_right_flipper.rotation.y = -cos(visual_component._animation_time * speed_mult) * 0.25
		else:
			# Slow idling water currents
			_front_left_flipper.rotation.z = sin(visual_component._animation_time * 1.5) * 0.08
			_front_right_flipper.rotation.z = -sin(visual_component._animation_time * 1.5) * 0.08
			
			_rear_left_flipper.rotation.y = 0
			_rear_right_flipper.rotation.y = 0


func _get_collision_box_size() -> Vector3:
	return Vector3(0.8, 0.4, 1.0)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.2, 0.0)


func _is_avian() -> bool:
	# Skip standard bipedal body bobbing calculations
	return true


## Override (LSP): Drops 1x Sand on death (Representing ocean beach sand).
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1) # Item ID 7: Sand Block
