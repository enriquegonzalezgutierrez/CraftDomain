# ==============================================================================
# Pathfile: res://src/Domain/Life/VillagerModelBuilder.gd
# Description: Concrete strategy implementing the procedural voxel model 
#              sculptor for the Common Villager entity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	skin_color: Color, 
	clothing_color: Color, 
	hair_color: Color, 
	biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	var pants_color := Color(0.18, 0.15, 0.12)
	_sculpt_villager_legs(visual_component, body_bob_node, pants_color)
	_build_custom_torso_robe(visual_component, body_bob_node, biome_id, clothing_color, pants_color)
	_sculpt_villager_head_and_eyes(visual_component, body_bob_node, skin_color, biome_id, hair_color)
	_sculpt_villager_folded_arms(visual_component, body_bob_node, clothing_color)


func _sculpt_villager_legs(visual_component: Object, parent: Node3D, pants_color: Color) -> void:
	var boots_color := Color(0.12, 0.12, 0.15)
	visual_component.call("create_box", parent, Vector3(0.16, 0.28, 0.16), Vector3(-0.1, 0.14, 0.0), pants_color)
	visual_component.call("create_box", parent, Vector3(0.16, 0.28, 0.16), Vector3(0.1, 0.14, 0.0), pants_color)
	visual_component.call("create_box", parent, Vector3(0.18, 0.08, 0.20), Vector3(-0.1, 0.04, -0.02), boots_color)
	visual_component.call("create_box", parent, Vector3(0.18, 0.08, 0.20), Vector3(0.1, 0.04, -0.02), boots_color)


func _sculpt_villager_head_and_eyes(visual_component: Object, parent: Node3D, skin_color: Color, biome_id: int, hair_color: Color) -> void:
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	parent.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.52, 0.35), Vector3(0, 0.26, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.10, 0.26, 0.12), Vector3(0, 0.06, -0.22), Color(0.55, 0.42, 0.32)) # Nose
	
	var l_eye := visual_component.call("create_box", head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.09, 0.15, -0.18), Color.WHITE) as MeshInstance3D
	visual_component.call("create_box", l_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.0, 0.75, 0.35))
	visual_component.set("left_eye", l_eye)
	
	var r_eye := visual_component.call("create_box", head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.09, 0.15, -0.18), Color.WHITE) as MeshInstance3D
	visual_component.call("create_box", r_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.0, 0.75, 0.35))
	visual_component.set("right_eye", r_eye)
	
	_build_custom_headwear(visual_component, head_node, biome_id, hair_color)


func _sculpt_villager_folded_arms(visual_component: Object, parent: Node3D, clothing_color: Color) -> void:
	var arms_node := Node3D.new()
	arms_node.name = "ArmsJoint"
	arms_node.position = Vector3(0, 0.65, -0.23)
	parent.add_child(arms_node)
	visual_component.set("arms_node", arms_node)
	visual_component.call("create_box", arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), clothing_color * 0.8)


func _build_custom_torso_robe(visual_component: Object, parent: Node3D, biome_id: int, base_color: Color, accessory_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Stripes)
			visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color.WHITE)
			visual_component.call("create_box", parent, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.75, 0), Color(0.12, 0.45, 0.82))
			visual_component.call("create_box", parent, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
			visual_component.call("create_box", parent, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.25, 0), Color(0.12, 0.45, 0.82))
		1: # Warp Plateau (Mario Plumber Dungarees)
			visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.85, 0.12, 0.12))
			visual_component.call("create_box", parent, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), Color(0.15, 0.35, 0.72))
		4: # Frostbite Glaciers (Winter white coat)
			visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.82, 0.82, 0.85))
			visual_component.call("create_box", parent, Vector3(0.48, 0.10, 0.48), Vector3(0, 0.15, 0), Color(0.98, 0.98, 0.98))
		_:
			# Default Plains Tunic
			visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), base_color)
			visual_component.call("create_box", parent, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), accessory_color)


func _build_custom_headwear(visual_component: Object, head_node: Node3D, biome_id: int, hair_color: Color) -> void:
	match biome_id:
		0: # Sailor Bandana
			visual_component.call("create_box", head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
		1: # Mario Plumber Cap
			visual_component.call("create_box", head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.52, 0), Color(0.85, 0.12, 0.12))
			visual_component.call("create_box", head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.48, -0.22), Color(0.85, 0.12, 0.12))
		4: # Winter Fur-Hood
			visual_component.call("create_box", head_node, Vector3(0.39, 0.48, 0.39), Vector3(0, 0.26, 0.02), Color(0.82, 0.82, 0.85))
			visual_component.call("create_box", head_node, Vector3(0.42, 0.52, 0.10), Vector3(0, 0.26, -0.15), Color(0.98, 0.98, 0.98))
		_:
			# Default Hair
			visual_component.call("create_box", head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.46, 0.03), hair_color)
