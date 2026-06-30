# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles only the unique 
#                geometry and loot drops for the chicken.
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              PROGRAMMATIC DESIGN: Constructs a highly detailed voxel chicken
#              entirely via code, featuring separate wings, a red comb (crest),
#              a red wattle (barba), a golden beak, and orange legs with claws.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_CHICKEN"


## Overrides: Assembles a premium detailed voxel chicken model programmatically using 3D boxes.
func _build_visual_representation() -> void:
	var white := Color(0.98, 0.96, 0.92) 
	var wing_grey := Color(0.92, 0.92, 0.94)
	var orange := Color(1.0, 0.6, 0.0)
	var beak_yellow := Color(1.0, 0.68, 0.0)
	var red := Color(0.92, 0.12, 0.15)
	
	# 1. Main Torso Body (White)
	_create_box(_visual_root, Vector3(0.36, 0.38, 0.46), Vector3(0, 0.36, 0), white)
	
	# Exent Side Wings (adds 3D volume and depth)
	_create_box(_visual_root, Vector3(0.06, 0.24, 0.32), Vector3(-0.21, 0.36, 0.02), wing_grey) # Left wing
	_create_box(_visual_root, Vector3(0.06, 0.24, 0.32), Vector3(0.21, 0.36, 0.02), wing_grey)  # Right wing
	
	# 2. Head Joint & Neck
	_head_node = Node3D.new()
	_head_node.name = "ChickenHead"
	_head_node.position = Vector3(0, 0.58, -0.2)
	_visual_root.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.22, 0.28, 0.22), Vector3(0, 0.08, 0), white) # Main head block
	
	# Red Comb/Crest (on top of the head)
	_create_box(_head_node, Vector3(0.06, 0.1, 0.22), Vector3(0, 0.27, 0.02), red)
	
	# Golden Yellow Beak
	_create_box(_head_node, Vector3(0.18, 0.1, 0.14), Vector3(0, 0.06, -0.16), beak_yellow)
	
	# Red Wattle (Barba under the beak)
	_create_box(_head_node, Vector3(0.08, 0.12, 0.08), Vector3(0, -0.05, -0.11), red)
	
	# Blinking Eyes with cyan-blue pupils
	_left_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(-0.12, 0.12, -0.12), Color.WHITE)
	_create_box(_left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.45, 0.85)) # Cyan pupil
	
	_right_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(0.12, 0.12, -0.12), Color.WHITE)
	_create_box(_right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.45, 0.85))
	
	# 3. Orange Legs & Claws (Centered at 2 sides)
	# Left Leg
	_create_box(_visual_root, Vector3(0.06, 0.16, 0.06), Vector3(-0.08, 0.1, -0.02), orange) # Leg shaft
	_create_box(_visual_root, Vector3(0.14, 0.03, 0.18), Vector3(-0.08, 0.015, -0.06), orange) # Claws
	
	# Right Leg
	_create_box(_visual_root, Vector3(0.06, 0.16, 0.06), Vector3(0.08, 0.1, -0.02), orange)
	_create_box(_visual_root, Vector3(0.14, 0.03, 0.18), Vector3(0.08, 0.015, -0.06), orange)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Flag used by the animation ticker to configure bouncy avian walks
func _is_avian() -> bool:
	return true


## Override: Drops 1x Fried Chicken on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
