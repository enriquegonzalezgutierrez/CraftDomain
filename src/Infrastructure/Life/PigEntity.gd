# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive Pig/Piglin.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              UX MODELING OVERHAUL (CLAY MOVIE PIGLIN):
#              - Assembled programmatically to perfectly match the high-fidelity 
#                clay-voxel pig warrior from the Minecraft Movie. Features a heavy 
#                stone helmet with a gold crest, glowing yellow eyes, a prominent 
#                pink snout, a sheathed obsidian sword on its back, and iron greaves.
#              WARNING FIX:
#              - Cleared all parser errors related to missing phantom methods. 
#                Properly modeled the sword using official `create_box` bindings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PigEntity.gd
# ==============================================================================
class_name PigEntity
extends PassiveEntity

# Handheld/Equipped weapon joint node for animations
var _weapon_joint: Node3D


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 2) # 2 Hearts of health (4 HP)
	name = "Entity_PIG"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var skin_pink := Color(1.0, 0.62, 0.72)         # Soft clay pink skin
	var snout_pink := Color(0.92, 0.38, 0.48)       # Warm pink snout and ears
	var steel_color := Color(0.12, 0.12, 0.14)      # Dark matte obsidian-steel armor
	var gold_trim := Color(0.85, 0.6, 0.15)         # Gold crown crest highlights
	var obsidian_black := Color(0.08, 0.08, 0.1)    # Deep black obsidian sword
	var eye_yellow := Color(1.0, 0.78, 0.12)        # Glowing yellow-gold eyes
	
	# 1. Base Legs & Iron Sabatons (Attached to the bouncing body bob joint of visual component)
	var _un1 := visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), steel_color) # Heavy steel boots
	var _un2 := visual_component.create_box(visual_component.body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.3, 0), skin_pink) # Left leg
	var _un3 := visual_component.create_box(visual_component.body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.3, 0), skin_pink)  # Right leg
	
	# 2. Torso Clothed Leather Harness & Iron breastplate
	var _un4 := visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_color) # Plate armor
	var _un5 := visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.08, 0.47), Vector3(0, 0.45, 0), Color(0.35, 0.22, 0.15)) # Leather belt
	
	# 3. Head Joint Setup (Heavy war-helmet!)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "PigHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	var _un6 := visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_pink) # Face core
	var _un7 := visual_component.create_box(visual_component.head_node, Vector3(0.22, 0.12, 0.12), Vector3(0, 0.05, -0.21), snout_pink) # Prominent pig snout
	
	# Heavy Iron Boar Helmet (Encloses the ears and skull)
	var _un8 := visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.26, 0.38), Vector3(0, 0.28, 0.01), steel_color) # Helmet crown
	var _un9 := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.22, 0.38), Vector3(-0.18, 0.18, 0.03), steel_color) # Left cheek guard
	var _un10 := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.22, 0.38), Vector3(0.18, 0.18, 0.03), steel_color)  # Right cheek guard
	
	# Golden Helmet Crest
	var _un11 := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.06, 0.40), Vector3(0, 0.41, 0), gold_trim)
	
	# Glowing Yellow-Gold Eyes (Assigned to visual component tracking)
	var eye_l := visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	var eye_r := visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	
	var em_mat := ORMMaterial3D.new()
	em_mat.albedo_color = eye_yellow
	em_mat.emission_enabled = true
	em_mat.emission = Color(1.0, 0.72, 0.1)
	em_mat.emission_energy_multiplier = 2.0
	eye_l.material_override = em_mat
	eye_r.material_override = em_mat
	
	# 4. Arms Folded / Heavy iron wrist guards
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	var _un12 := visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), steel_color * 0.85)
	var _un13 := visual_component.create_box(visual_component.arms_node, Vector3(0.60, 0.04, 0.25), Vector3(0, 0, 0), gold_trim) # Gold cuffs
	
	# 5. Sheathed Obsidian Sword on back (Mounted to the body bob joint)
	_weapon_joint = Node3D.new()
	_weapon_joint.name = "ObisidianSwordHarness"
	_weapon_joint.position = Vector3(-0.2, 0.5, 0.24)
	_weapon_joint.rotation = Vector3(0, 0, deg_to_rad(-135))
	visual_component.body_bob_node.add_child(_weapon_joint)
	
	# Model the sword pieces
	var _un14 := visual_component.create_box(_weapon_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), obsidian_black)  # Blade
	var _un15 := visual_component.create_box(_weapon_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), gold_trim)       # Guard
	var _un16 := visual_component.create_box(_weapon_joint, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.1, 0), skin_pink)          # Grip (matching skin leather)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


## Override (LSP): Drops 1x Fried Chicken (Meat proxy) on death to reward the player.
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	var _un1 := inv.add_item(16, 1)
