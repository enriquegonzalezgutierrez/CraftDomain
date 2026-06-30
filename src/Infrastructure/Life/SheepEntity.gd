# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive sheep.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles only the unique 
#                geometry and loot drops for the sheep.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              PROGRAMMATIC DESIGN: Constructs a detailed voxel sheep via code.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SheepEntity.gd
# ==============================================================================
class_name SheepEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_SHEEP"


## Overrides: Assembles a fluffy voxel sheep model programmatically using 3D boxes.
func _build_visual_representation() -> void:
	# Main Fluffy Torso
	_create_box(_visual_root, Vector3(0.72, 0.55, 0.92), Vector3(0, 0.38, 0), Color(0.95, 0.95, 0.98))
	
	# Head Joint & Face
	_head_node = Node3D.new()
	_head_node.name = "SheepHead"
	_head_node.position = Vector3(0, 0.65, -0.48)
	_visual_root.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.35, 0.35), Vector3(0, 0, 0), Color(0.95, 0.75, 0.65)) # Face
	_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.14, 0), Color(0.95, 0.95, 0.98)) # Wool cap
	
	# Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.07, 0.07, 0.02), Vector3(-0.14, 0.03, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	
	_right_eye = _create_box(_head_node, Vector3(0.07, 0.07, 0.02), Vector3(0.14, 0.03, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	
	# 4 Dark Grey Legs
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override: Drops 1x Leaves Block (Wool proxy) and 1x Meat on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(5, 1)  # Item ID 5: Leaves (Acting as fluffy wool)
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
