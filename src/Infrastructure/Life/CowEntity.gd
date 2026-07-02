# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive cow.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              UX MODELING OVERHAUL (CLAY MOVIE COW):
#              - Assembled programmatically to perfectly match the high-fidelity 
#                clay-voxel cow from the Minecraft Movie. Features a rich dark-brown 
#                base fur, asymmetric white patch overlays on shoulders and hips, 
#                a highly detailed 4-teat pink udder, a prominent pink snout, 
#                curved horns, and segmented white-socked legs.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CowEntity.gd
# ==============================================================================
class_name CowEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health (6 HP)
	name = "Entity_COW"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var brown_base := Color(0.28, 0.22, 0.18)      # Deep dark-brown clay fur
	var patch_white := Color(0.95, 0.95, 0.98)     # Off-white patch paint
	var pink_snout := Color(0.92, 0.65, 0.65)      # Warm pink snout and udders
	var horn_cream := Color(0.92, 0.88, 0.82)      # Creamy horn ivory
	var hoof_color := Color(0.18, 0.18, 0.20)      # Dark slate hooves
	var eye_black := Color(0.08, 0.08, 0.1)        # Warm dark eyes
	
	# 1. Main Torso Body (Dark Brown, attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.75, 0.72, 1.15), Vector3(0, 0.55, 0), brown_base)
	
	# Asymmetric White Patch Overlays (Adds organic voxel depth)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.77, 0.42, 0.35), Vector3(0, 0.62, -0.22), patch_white)  # Front shoulder white patch
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.77, 0.48, 0.32), Vector3(0, 0.50, 0.32), patch_white)   # Rear hip white patch
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.18, 0.22), Vector3(-0.18, 0.83, 0.05), patch_white) # Spine white patch
	
	# 2. Detailed Pink Udders (Underneath the belly with 4 individual teats!)
	var udder_base := visual_component.create_box(visual_component.body_bob_node, Vector3(0.28, 0.08, 0.28), Vector3(0, 0.16, 0.18), pink_snout)
	
	# Modeling the 4 tiny hanging teats dynamically (Flyweight offset boxes)
	visual_component.create_box(udder_base, Vector3(0.04, 0.08, 0.04), Vector3(-0.06, -0.06, -0.06), pink_snout) # Front Left Teat
	visual_component.create_box(udder_base, Vector3(0.04, 0.08, 0.04), Vector3(0.06, -0.06, -0.06), pink_snout)  # Front Right Teat
	visual_component.create_box(udder_base, Vector3(0.04, 0.08, 0.04), Vector3(-0.06, -0.06, 0.06), pink_snout)  # Rear Left Teat
	visual_component.create_box(udder_base, Vector3(0.04, 0.08, 0.04), Vector3(0.06, -0.06, 0.06), pink_snout)   # Rear Right Teat
	
	# 3. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "CowHead"
	visual_component.head_node.position = Vector3(0, 0.85, -0.6)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.08, 0), brown_base) # Main head block
	visual_component.create_box(visual_component.head_node, Vector3(0.44, 0.22, 0.22), Vector3(0, 0.18, 0.08), patch_white) # Head spot patch
	visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.18, 0.18), Vector3(0, -0.04, -0.21), pink_snout) # Snout/Nose
	
	# Curved Creamy Horns
	visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.18, 0.06), Vector3(-0.23, 0.32, 0.05), horn_cream)
	visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.18, 0.06), Vector3(0.23, 0.32, 0.05), horn_cream)
	
	# Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.18, 0.12, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), eye_black) # Dark pupil
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.18, 0.12, -0.21), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), eye_black)
	
	# 4. Segmented Legs with White "Socks" & Dark Hooves (Attached to the body bob joint)
	# Front Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, -0.38), brown_base)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.12, 0.20), Vector3(-0.25, 0.16, -0.38), patch_white) # Socks
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, -0.38), hoof_color) # Hoof
	
	# Front Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, -0.38), brown_base)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.12, 0.20), Vector3(0.25, 0.16, -0.38), patch_white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, -0.38), hoof_color)
	
	# Rear Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(-0.25, 0.22, 0.38), brown_base)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.12, 0.20), Vector3(-0.25, 0.16, 0.38), patch_white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(-0.25, 0.03, 0.38), hoof_color)
	
	# Rear Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.32, 0.18), Vector3(0.25, 0.22, 0.38), brown_base)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.12, 0.20), Vector3(0.25, 0.16, 0.38), patch_white)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.06, 0.18), Vector3(0.25, 0.03, 0.38), hoof_color)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Override (LSP): Drops 1x Dirt Block (Leather proxy) and 1x Meat on death.
func _drop_loot(inv: IInventory) -> void:
	# Item ID 2: Dirt (Acting as leather)
	var _un1 := inv.add_item(2, 1)  
	# Item ID 16: Fried Chicken (acting as meat)
	var _un2 := inv.add_item(16, 1)
