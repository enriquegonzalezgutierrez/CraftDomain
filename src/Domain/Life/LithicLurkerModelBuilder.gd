# ==============================================================================
# Pathfile: res://src/Domain/Life/LithicLurkerModelBuilder.gd
# Description: Concrete strategy implementing the voxel model sculptor 
#              for the Lithic Lurker multi-phase boss.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Sculpting logic is isolated here. 
#   Monolithic drawing methods have been decomposed to under 20 lines each.
# - Open-Closed Principle (OCP): Adds a new boss model dynamically without
#   modifying the core voxel representation classes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LithicLurkerModelBuilder
extends IVoxelModelBuilder


## Concrete Contract: Assembles the massive stone body and glowing cyan core
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
		
	_build_torso_and_legs(visual_component, body_bob_node)
	_build_massive_arms(visual_component, body_bob_node)
	_build_head_and_eyes(visual_component, body_bob_node)


func _build_torso_and_legs(visual_component: Object, parent: Node3D) -> void:
	var stone_dark := Color(0.18, 0.18, 0.20)
	var stone_light := Color(0.32, 0.32, 0.35)
	var core_cyan := Color(0.0, 0.95, 0.95)
	
	# Stumpy basalt legs
	visual_component.call("create_box", parent, Vector3(0.6, 0.5, 0.6), Vector3(-0.4, 0.25, 0.0), stone_dark)
	visual_component.call("create_box", parent, Vector3(0.6, 0.5, 0.6), Vector3(0.4, 0.25, 0.0), stone_dark)
	
	# Massive main torso
	visual_component.call("create_box", parent, Vector3(1.8, 1.6, 1.4), Vector3(0.0, 1.3, 0.0), stone_light)
	
	# Glowing Cyan Power Core (Exposed directly on the chest)
	var core: MeshInstance3D = visual_component.call("create_box", parent, Vector3(0.5, 0.5, 0.2), Vector3(0.0, 1.4, 0.75), core_cyan) as MeshInstance3D
	_apply_emissive_material(core, core_cyan)


func _build_massive_arms(visual_component: Object, parent: Node3D) -> void:
	var stone_dark := Color(0.18, 0.18, 0.20)
	var stone_light := Color(0.32, 0.32, 0.35)
	
	# Craggy extended shoulders
	visual_component.call("create_box", parent, Vector3(0.7, 0.6, 0.8), Vector3(-1.25, 1.8, 0.0), stone_dark)
	visual_component.call("create_box", parent, Vector3(0.7, 0.6, 0.8), Vector3(1.25, 1.8, 0.0), stone_dark)
	
	# Left Arm extending to the floor
	var l_arm := Node3D.new()
	l_arm.position = Vector3(-1.25, 1.5, 0.0)
	parent.add_child(l_arm)
	visual_component.call("create_box", l_arm, Vector3(0.5, 1.8, 0.6), Vector3(0.0, -0.9, 0.0), stone_light)
	visual_component.set("left_arm_joint", l_arm)
	
	# Right Arm extending to the floor
	var r_arm := Node3D.new()
	r_arm.position = Vector3(1.25, 1.5, 0.0)
	parent.add_child(r_arm)
	visual_component.call("create_box", r_arm, Vector3(0.5, 1.8, 0.6), Vector3(0.0, -0.9, 0.0), stone_light)
	visual_component.set("right_arm_joint", r_arm)


func _build_head_and_eyes(visual_component: Object, parent: Node3D) -> void:
	var stone_dark := Color(0.18, 0.18, 0.20)
	var core_cyan := Color(0.0, 0.95, 0.95)
	
	var head := Node3D.new()
	head.name = "HumanHead" # Maintains string-lookup compatibility with visual animations
	head.position = Vector3(0.0, 2.1, 0.0)
	parent.add_child(head)
	visual_component.set("head_node", head)
	
	visual_component.call("create_box", head, Vector3(0.7, 0.6, 0.7), Vector3(0.0, 0.3, 0.0), stone_dark)
	
	# Cyber-glitched aggressive eyes
	var l_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.15, 0.15, 0.05), Vector3(-0.2, 0.35, 0.36), core_cyan) as MeshInstance3D
	var r_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.15, 0.15, 0.05), Vector3(0.2, 0.35, 0.36), core_cyan) as MeshInstance3D
	
	_apply_emissive_material(l_eye, core_cyan)
	_apply_emissive_material(r_eye, core_cyan)


func _apply_emissive_material(mesh_instance: MeshInstance3D, glow_color: Color) -> void:
	if not is_instance_valid(mesh_instance):
		return
		
	var mat := mesh_instance.material_override as StandardMaterial3D
	if is_instance_valid(mat):
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 2.5


func get_collision_box_size() -> Vector3:
	return Vector3(1.8, 2.5, 1.4) 


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 1.25, 0.0)
