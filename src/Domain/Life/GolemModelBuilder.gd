# ==============================================================================
# Pathfile: res://src/Domain/Life/GolemModelBuilder.gd
# Description: Concrete strategy implementing the procedural voxel model 
#              sculptor for the Colossus Iron Golem entity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GolemModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	_skin_color: Color, 
	_clothing_color: Color, 
	_hair_color: Color, 
	_biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	_sculpt_golem_torso(visual_component, body_bob_node)


func _sculpt_golem_torso(visual_component: Object, parent: Node3D) -> void:
	var stone := Color(0.48, 0.48, 0.50)
	var moss := Color(0.25, 0.45, 0.18)
	
	# Torso and Mossy Collar
	visual_component.call("create_box", parent, Vector3(1.10, 1.45, 0.85), Vector3(0, 0.725, 0), stone) # Torso
	visual_component.call("create_box", parent, Vector3(1.14, 0.32, 0.89), Vector3(0, 1.22, 0), moss)  # Mossy collar
