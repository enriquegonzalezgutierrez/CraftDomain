# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Model Strategies)
# Class: DruidModelBuilder
# Description: Concrete strategy implementing the voxel model sculptor 
#              for the Nature Forest Druid.
# ==============================================================================
class_name DruidModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	skin_color: Color, 
	_clothing_color: Color, 
	hair_color: Color, 
	_biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	# Legs, Torso Robe
	visual_component.call("create_box", body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.15, 0.1, 0.08)) # Boots
	visual_component.call("create_box", body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.18, 0.45, 0.15)) # Robe
	
	# Head
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	body_bob_node.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
	visual_component.call("create_box", head_node, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.28, 0), Color(0.85, 0.6, 0.15)) # Crown
