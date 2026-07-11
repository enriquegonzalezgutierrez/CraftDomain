# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Model Strategies)
# Class: GuardModelBuilder
# Description: Concrete strategy implementing the voxel model sculptor 
#              for the Armored Guard Knight.
# ==============================================================================
class_name GuardModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	skin_color: Color, 
	_clothing_color: Color, 
	_hair_color: Color, 
	_biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	var steel_armor := Color(0.40, 0.40, 0.45)
	var iron_color := Color(0.55, 0.55, 0.60)
	
	# Legs, Torso, Pauldrons
	visual_component.call("create_box", body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), steel_armor)
	visual_component.call("create_box", body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_armor)
	visual_component.call("create_box", body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(-0.25, 0.75, 0), iron_color) # Pauldron L
	visual_component.call("create_box", body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(0.25, 0.75, 0), iron_color)  # Pauldron R
	
	# Head (Knight helmet)
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	body_bob_node.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.38, 0.22, 0.38), Vector3(0, 0.32, 0), steel_armor) # Helmet Dome
	visual_component.call("create_box", head_node, Vector3(0.05, 0.18, 0.04), Vector3(0, 0.19, -0.20), iron_color)  # Visor
	visual_component.call("create_box", head_node, Vector3(0.04, 0.28, 0.16), Vector3(0, 0.48, 0.05), Color(0.85, 0.12, 0.15)) # Plume
	
	# Voxel Sword Joint
	var sword_joint := Node3D.new()
	sword_joint.name = "IronSwordJoint"
	sword_joint.position = Vector3(-0.2, 0.5, 0.24)
	sword_joint.rotation = Vector3(0, 0, deg_to_rad(-135))
	body_bob_node.add_child(sword_joint)
	visual_component.set("_sword_joint", sword_joint)
	
	visual_component.call("create_box", sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), iron_color) # Blade
	visual_component.call("create_box", sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), Color(0.85, 0.6, 0.15)) # Guard
