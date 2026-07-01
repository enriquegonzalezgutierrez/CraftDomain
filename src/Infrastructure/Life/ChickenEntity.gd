# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_CHICKEN"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var white := Color(0.98, 0.96, 0.92) 
	var wing_grey := Color(0.92, 0.92, 0.94)
	var orange := Color(1.0, 0.6, 0.0)
	var beak_yellow := Color(1.0, 0.68, 0.0)
	var red := Color(0.92, 0.12, 0.15)
	
	# 1. Main Torso Body (White, attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.36, 0.38, 0.46), Vector3(0, 0.36, 0), white)
	
	# Exent Side Wings (adds 3D volume and depth)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.24, 0.32), Vector3(-0.21, 0.36, 0.02), wing_grey) # Left wing
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.24, 0.32), Vector3(0.21, 0.36, 0.02), wing_grey)  # Right wing
	
	# 2. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "ChickenHead"
	visual_component.head_node.position = Vector3(0, 0.58, -0.2)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.22, 0.28, 0.22), Vector3(0, 0.08, 0), white) # Main head block
	
	# Red Comb/Crest (on top of the head)
	visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.1, 0.22), Vector3(0, 0.27, 0.02), red)
	
	# Golden Yellow Beak
	visual_component.create_box(visual_component.head_node, Vector3(0.18, 0.1, 0.14), Vector3(0, 0.06, -0.16), beak_yellow)
	
	# Red Wattle (Barba under the beak)
	visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.12, 0.08), Vector3(0, -0.05, -0.11), red)
	
	# Blinking Eyes with cyan-blue pupils (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.06, 0.02), Vector3(-0.12, 0.12, -0.12), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.45, 0.85)) # Cyan pupil
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.06, 0.02), Vector3(0.12, 0.12, -0.12), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.45, 0.85))
	
	# 3. Orange Legs & Claws (Centered on 2 sides, bobbing with the torso)
	# Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.16, 0.06), Vector3(-0.08, 0.1, -0.02), orange) # Leg shaft
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.14, 0.03, 0.18), Vector3(-0.08, 0.015, -0.06), orange) # Claws
	
	# Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.16, 0.06), Vector3(0.08, 0.1, -0.02), orange)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.14, 0.03, 0.18), Vector3(0.08, 0.015, -0.06), orange)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Flag used by the animation ticker to configure bouncy avian walks
func _is_avian() -> bool:
	return true


## Override (LSP): Drops 1x Fried Chicken on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
