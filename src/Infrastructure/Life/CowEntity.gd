# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive cow.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles cow-specific
#                mesh compositions and hitboxes.
#              - Liskov Substitution Principle (LSP): Correctly overrides the 
#                abstract visualization methods of PassiveEntity.
#              PROGRAMMATIC DESIGN: Constructs a highly detailed, spotted Holstein
#              voxel cow entirely via code.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CowEntity.gd
# ==============================================================================
class_name CowEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_COW"


## Overrides: Assembles a premium spotted voxel cow model programmatically using 3D boxes.
func _build_visual_representation() -> void:
	var white := Color(0.98, 0.96, 0.92) 
	var black := Color(0.12, 0.12, 0.12)
	var pink := Color(0.92, 0.62, 0.62)
	var ivory := Color(0.95, 0.92, 0.85)
	var hoof_color := Color(0.25, 0.25, 0.27)
	
	# 1. Main Torso Body (Base White)
	_create_box(_visual_root, Vector3(0.75, 0.72, 1.15), Vector3(0, 0.55, 0), white)
	
	# Spotted Plates (Black patches overlayed programmatically for voxel depth)
	_create_box(_visual_root, Vector3(0.77, 0.35, 0.45), Vector3(0, 0.65, -0.22), black) # Front shoulder patch
	_create_box(_visual_root, Vector3(0.77, 0.42, 0.32), Vector3(0, 0.55, 0.32), black)  # Rear hip patch
	_create_box(_visual_root, Vector3(0.45, 0.18, 0.22), Vector3(-0.18, 0.83, 0.05), black) # Top spine patch
	
	# 2. Pink Udders (Underneath the belly)
	_create_box(_visual_root, Vector3(0.28, 0.08, 0.28), Vector3(0, 0.16, 0.18), pink)
	
	# 3. Head Joint & Neck (Elevated on front)
	_head_node = Node3D.new()
	_head_node.name = "CowHead"
	_head_node.position = Vector3(0, 0.85, -0.6)
	_visual_root.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.08, 0), white) # Main head block
	_create_box(_head_node, Vector3(0.44, 0.22, 0.22), Vector3(0, 0.18, 0.08), black) # Head spot patch
	_create_box(_head_node, Vector3(0.32, 0.18, 0.18), Vector3(0, -0.04, -0.21), pink) # Snout/Nose
	
	# Ivory Beige Horns
	_create_box(_head_node, Vector3(0.06, 0.18, 0.06), Vector3(-0.23, 0.32, 0.05), ivory)
	_create_box(_head_node, Vector3(0.06, 0.18, 0.06), Vector3(0.23, 0.32, 0.05), ivory)
	
	# Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.18, 0.12, -0.21), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15)) # Dark pupil
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.18, 0.12, -0.21), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	
	# 4. Detailed White Legs & Dark Grey Hooves (Positioned at 4 corners)
	# Front Left Leg
	_create_box(_visual_root, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, -0.38), white)
	_create_box(_visual_root, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, -0.38), hoof_color) # Hoof
	
	# Front Right Leg
	_create_box(_visual_root, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, -0.38), white)
	_create_box(_visual_root, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, -0.38), hoof_color)
	
	# Rear Left Leg
	_create_box(_visual_root, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, 0.38), white)
	_create_box(_visual_root, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, 0.38), hoof_color)
	
	# Rear Right Leg
	_create_box(_visual_root, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, 0.38), white)
	_create_box(_visual_root, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, 0.38), hoof_color)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override: Drops 1x Dirt Block (Leather proxy) and 1x Meat on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(2, 1)  # Item ID 2: Dirt (Acting as leather)
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
