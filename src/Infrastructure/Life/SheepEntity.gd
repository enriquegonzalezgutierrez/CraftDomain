# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive sheep.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SheepEntity.gd
# ==============================================================================
class_name SheepEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_SHEEP"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	# 1. Main Fluffy Torso (Attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.72, 0.55, 0.92), Vector3(0, 0.38, 0), Color(0.95, 0.95, 0.98))
	
	# 2. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "SheepHead"
	visual_component.head_node.position = Vector3(0, 0.65, -0.48)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.35, 0.35), Vector3(0, 0, 0), Color(0.95, 0.75, 0.65)) # Face
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.14, 0), Color(0.95, 0.95, 0.98)) # Wool cap
	
	# Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.07, 0.07, 0.02), Vector3(-0.14, 0.03, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.07, 0.07, 0.02), Vector3(0.14, 0.03, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	
	# 3. 4 Dark Grey Legs (Quadruped support, bobbing with the torso)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override (LSP): Drops 1x Leaves Block (Wool proxy) and 1x Meat on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(5, 1)  # Item ID 5: Leaves (Acting as fluffy wool)
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
