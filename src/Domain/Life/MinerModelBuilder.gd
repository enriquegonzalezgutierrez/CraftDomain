# ==============================================================================
# Pathfile: res://src/Domain/Life/MinerModelBuilder.gd
# Description: Concrete strategy implementing the procedural voxel model 
#              sculptor for the Cavern Spotlight Miner entity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MinerModelBuilder
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
		
	_sculpt_miner_body(visual_component, body_bob_node, clothing_color)
	_sculpt_miner_head(visual_component, body_bob_node, skin_color)


func _sculpt_miner_body(visual_component: Object, parent: Node3D, clothing_color: Color) -> void:
	visual_component.call("create_box", parent, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.12, 0.1, 0.08)) # Boots
	visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), clothing_color)
	visual_component.call("create_box", parent, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.35, 0), Color(0.38, 0.4, 0.42)) # Dungarees


func _sculpt_miner_head(visual_component: Object, parent: Node3D, skin_color: Color) -> void:
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	parent.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.95, 0.78, 0.12)) # Hard-hat
	_attach_headlamp_light(visual_component, head_node)


func _attach_headlamp_light(visual_component: Object, head_node: Node3D) -> void:
	var lamp_casing: MeshInstance3D = visual_component.call("create_box", head_node, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.06, -0.22), Color(0.2, 0.2, 0.22))
	var lamp_lens: MeshInstance3D = visual_component.call("create_box", lamp_casing, Vector3(0.06, 0.06, 0.02), Vector3(0, 0, -0.035), Color(0.0, 0.95, 0.95))
	
	var headlamp_light := SpotLight3D.new()
	headlamp_light.name = "HeadlampBeam"
	headlamp_light.light_color = Color(0.92, 0.95, 1.0)
	headlamp_light.light_energy = 2.4
	headlamp_light.spot_range = 16.0
	headlamp_light.shadow_enabled = true
	lamp_lens.add_child(headlamp_light)
