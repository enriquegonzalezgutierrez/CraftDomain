# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive pig.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PigEntity.gd
# ==============================================================================
class_name PigEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_PIG"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var body_color := Color(1.0, 0.62, 0.72)
	var nose_color := Color(0.92, 0.38, 0.48)
	
	# 1. Main Torso Body (Attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.7, 0.45, 0.9), Vector3(0, 0.35, 0), body_color)
	
	# 2. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "PigHead"
	visual_component.head_node.position = Vector3(0, 0.6, -0.45)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.4, 0.4, 0.4), Vector3(0, 0, 0), Color(1.0, 0.58, 0.68))
	visual_component.create_box(visual_component.head_node, Vector3(0.22, 0.12, 0.12), Vector3(0, -0.1, -0.22), nose_color)
	
	# Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.16, 0.05, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.16, 0.05, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	
	# 3. 4 Legs (Quadruped support, bobbing with the torso)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, -0.28), body_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, -0.28), body_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, 0.28), body_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, 0.28), body_color)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override (LSP): Drops 1x Fried Chicken (Meat proxy) on death to reward the player.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
