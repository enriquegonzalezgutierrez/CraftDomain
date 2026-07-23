# ==============================================================================
# Pathfile: res://src/Domain/Life/FarmerModelBuilder.gd
# Description: Concrete strategy implementing the procedural voxel model 
#              sculptor for the Agricultural Farmer entity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FarmerModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	skin_color: Color, 
	clothing_color: Color, 
	_hair_color: Color, 
	_biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	_sculpt_farmer_body(visual_component, body_bob_node, clothing_color)
	_sculpt_farmer_head(visual_component, body_bob_node, skin_color)
	_sculpt_farmer_hoe(visual_component, body_bob_node)


func _sculpt_farmer_body(visual_component: Object, parent: Node3D, clothing_color: Color) -> void:
	var denim_color := Color(0.20, 0.35, 0.55)
	visual_component.call("create_box", parent, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.18, 0.14, 0.11)) # Boots
	visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), clothing_color)
	visual_component.call("create_box", parent, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), denim_color) # Overalls


func _sculpt_farmer_head(visual_component: Object, parent: Node3D, skin_color: Color) -> void:
	var hat_color := Color(0.88, 0.78, 0.42)
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	parent.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.65, 0.03, 0.65), Vector3(0, 0.36, 0), hat_color) # Straw hat brim


func _sculpt_farmer_hoe(visual_component: Object, parent: Node3D) -> void:
	var hoe_joint := Node3D.new()
	hoe_joint.name = "HarvestHoeJoint"
	hoe_joint.position = Vector3(0.18, 0.52, 0.24)
	hoe_joint.rotation = Vector3(0, 0, deg_to_rad(45))
	parent.add_child(hoe_joint)
	visual_component.set("_hoe_joint", hoe_joint)
	
	visual_component.call("create_box", hoe_joint, Vector3(0.04, 0.52, 0.04), Vector3(0, 0, 0), Color(0.35, 0.22, 0.15)) # Handle shaft
	visual_component.call("create_box", hoe_joint, Vector3(0.10, 0.18, 0.04), Vector3(0, 0.21, -0.12), Color(0.5, 0.5, 0.52)) # Blade
