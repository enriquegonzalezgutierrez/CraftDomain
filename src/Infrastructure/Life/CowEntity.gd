# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive cow.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CowEntity.gd
# ==============================================================================
class_name CowEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health
	name = "Entity_COW"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var white := Color(0.98, 0.96, 0.92) 
	var black := Color(0.12, 0.12, 0.12)
	var pink := Color(0.92, 0.62, 0.62)
	var ivory := Color(0.95, 0.92, 0.85)
	var hoof_color := Color(0.25, 0.25, 0.27)
	
	# 1. Main Torso Body (Base White, attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.75, 0.72, 1.15), Vector3(0, 0.55, 0), white)
	
	# Spotted Plates (Black patches overlayed programmatically for voxel depth)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.77, 0.35, 0.45), Vector3(0, 0.65, -0.22), black) # Front shoulder patch
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.77, 0.42, 0.32), Vector3(0, 0.55, 0.32), black)  # Rear hip patch
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.18, 0.22), Vector3(-0.18, 0.83, 0.05), black) # Top spine patch
	
	# 2. Pink Udders (Underneath the belly)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.28, 0.08, 0.28), Vector3(0, 0.16, 0.18), pink)
	
	# 3. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "CowHead"
	visual_component.head_node.position = Vector3(0, 0.85, -0.6)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.08, 0), white) # Main head block
	visual_component.create_box(visual_component.head_node, Vector3(0.44, 0.22, 0.22), Vector3(0, 0.18, 0.08), black) # Head spot patch
	visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.18, 0.18), Vector3(0, -0.04, -0.21), pink) # Snout/Nose
	
	# Ivory Beige Horns
	visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.18, 0.06), Vector3(-0.23, 0.32, 0.05), ivory)
	visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.18, 0.06), Vector3(0.23, 0.32, 0.05), ivory)
	
	# Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.18, 0.12, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15)) # Dark pupil
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.18, 0.12, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	
	# 4. Detailed White Legs & Dark Grey Hooves (Positioned at 4 corners, bobbing with the torso)
	# Front Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, -0.38), white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, -0.38), hoof_color) # Hoof
	
	# Front Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, -0.38), white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, -0.38), hoof_color)
	
	# Rear Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, 0.38), white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, 0.38), hoof_color)
	
	# Rear Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, 0.38), white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, 0.38), hoof_color)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override (LSP): Drops 1x Dirt Block (Leather proxy) and 1x Meat on death.
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(2, 1)  # Item ID 2: Dirt (Acting as leather)
	inv.add_item(16, 1) # Item ID 16: Fried Chicken
