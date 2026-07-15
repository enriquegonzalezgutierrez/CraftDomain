# ==============================================================================
# Pathfile: res://src/Domain/Life/ObsidianColossusModelBuilder.gd
# Description: Concrete strategy implementing the voxel model sculptor 
#              for the Obsidian Colossus (Act III Boss).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Sculpting logic is isolated here. 
#   Complex model geometries have been decomposed to under 20 lines each.
# - Open-Closed Principle (OCP): Adds a new boss model dynamically without
#   modifying the core voxel representation classes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ObsidianColossusModelBuilder
extends IVoxelModelBuilder


## Concrete Contract: Sculpts the colossal volcanic body, horns, and magma channels
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
		
	_build_volcanic_legs_and_base(visual_component, body_bob_node)
	_build_obsidian_torso_and_veins(visual_component, body_bob_node)
	_build_colossal_arms(visual_component, body_bob_node)
	_build_horned_head_and_faro(visual_component, body_bob_node)


func _build_volcanic_legs_and_base(visual_component: Object, parent: Node3D) -> void:
	var obsidian_dark := Color(0.08, 0.05, 0.12) # Deep purple-black volcanic glass
	
	# Thick, robust stone stumps
	visual_component.call("create_box", parent, Vector3(0.7, 0.7, 0.7), Vector3(-0.5, 0.35, 0.0), obsidian_dark)
	visual_component.call("create_box", parent, Vector3(0.7, 0.7, 0.7), Vector3(0.4, 0.35, 0.0), obsidian_dark)


func _build_obsidian_torso_and_veins(visual_component: Object, parent: Node3D) -> void:
	var obsidian_dark := Color(0.08, 0.05, 0.12)
	var lava_orange := Color(1.0, 0.35, 0.0) # Incandescent magma
	
	# Colossal obsidian torso
	visual_component.call("create_box", parent, Vector3(2.2, 2.0, 1.6), Vector3(0.0, 1.7, 0.0), obsidian_dark)
	
	# Lava channels/veins running down the chest plate
	var vein_l: MeshInstance3D = visual_component.call("create_box", parent, Vector3(0.12, 1.2, 0.05), Vector3(-0.4, 1.7, 0.81), lava_orange) as MeshInstance3D
	var vein_r: MeshInstance3D = visual_component.call("create_box", parent, Vector3(0.12, 1.2, 0.05), Vector3(0.4, 1.7, 0.81), lava_orange) as MeshInstance3D
	
	_apply_emissive_material(vein_l, lava_orange)
	_apply_emissive_material(vein_r, lava_orange)


func _build_colossal_arms(visual_component: Object, parent: Node3D) -> void:
	var obsidian_dark := Color(0.08, 0.05, 0.12)
	
	# Giant shoulders
	visual_component.call("create_box", parent, Vector3(0.8, 0.8, 0.9), Vector3(-1.5, 2.3, 0.0), obsidian_dark)
	visual_component.call("create_box", parent, Vector3(0.8, 0.8, 0.9), Vector3(1.5, 2.3, 0.0), obsidian_dark)
	
	# Left Arm extending to the floor
	var l_arm := Node3D.new()
	l_arm.position = Vector3(-1.5, 1.9, 0.0)
	parent.add_child(l_arm)
	visual_component.call("create_box", l_arm, Vector3(0.6, 2.2, 0.7), Vector3(0.0, -1.1, 0.0), obsidian_dark)
	visual_component.set("left_arm_joint", l_arm)
	
	# Right Arm extending to the floor
	var r_arm := Node3D.new()
	r_arm.position = Vector3(1.5, 1.9, 0.0)
	parent.add_child(r_arm)
	visual_component.call("create_box", r_arm, Vector3(0.6, 2.2, 0.7), Vector3(0.0, -1.1, 0.0), obsidian_dark)
	visual_component.set("right_arm_joint", r_arm)


func _build_horned_head_and_faro(visual_component: Object, parent: Node3D) -> void:
	var obsidian_dark := Color(0.08, 0.05, 0.12)
	var lava_orange := Color(1.0, 0.35, 0.0)
	
	var head := Node3D.new()
	head.name = "HumanHead" # Maintains animation lookup compatibility
	head.position = Vector3(0.0, 2.7, 0.0)
	parent.add_child(head)
	visual_component.set("head_node", head)
	
	visual_component.call("create_box", head, Vector3(0.8, 0.7, 0.8), Vector3(0.0, 0.35, 0.0), obsidian_dark)
	
	# Dual Obsidian Horns rising upwards
	visual_component.call("create_box", head, Vector3(0.12, 0.45, 0.12), Vector3(-0.35, 0.8, 0.0), obsidian_dark)
	visual_component.call("create_box", head, Vector3(0.12, 0.45, 0.12), Vector3(0.35, 0.8, 0.0), obsidian_dark)
	
	# Glowing eyes
	var l_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.18, 0.12, 0.05), Vector3(-0.22, 0.35, 0.41), lava_orange) as MeshInstance3D
	var r_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.18, 0.12, 0.05), Vector3(0.22, 0.35, 0.41), lava_orange) as MeshInstance3D
	
	_apply_emissive_material(l_eye, lava_orange)
	_apply_emissive_material(r_eye, lava_orange)


func _apply_emissive_material(mesh_instance: MeshInstance3D, glow_color: Color) -> void:
	if not is_instance_valid(mesh_instance):
		return
		
	var mat := mesh_instance.material_override as StandardMaterial3D
	if is_instance_valid(mat):
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 3.0
		mat.roughness = 0.05 # Highly glossy volcanic glass reflections


func get_collision_box_size() -> Vector3:
	return Vector3(2.2, 3.5, 1.8) 


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 1.75, 0.0)
