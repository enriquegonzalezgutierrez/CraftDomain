# ==============================================================================
# Pathfile: res://src/Domain/Life/WeaverMalakorModelBuilder.gd
# Description: Concrete strategy implementing the voxel model sculptor 
#              for Weaver Malakor, the final boss (Act IV).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Sculpting logic is isolated here. 
#   Modular helpers are kept under 20 lines each.
# - Open-Closed Principle (OCP): Adds a new boss model dynamically without
#   modifying the core voxel representation classes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeaverMalakorModelBuilder
extends IVoxelModelBuilder


## Concrete Contract: Sculpts the celestial robes, folded arms, and levitating crown
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
		
	_build_celestial_robe(visual_component, body_bob_node)
	_build_folded_arms(visual_component, body_bob_node)
	_build_weaver_head_and_eyes(visual_component, body_bob_node)


func _build_celestial_robe(visual_component: Object, parent: Node3D) -> void:
	var robe_white := Color(0.95, 0.95, 0.98)
	var gold_trim := Color(0.85, 0.65, 0.15) # Chrono-Loom gold thread
	
	# Lower skirt/robe base
	visual_component.call("create_box", parent, Vector3(0.42, 0.35, 0.42), Vector3(0, 0.175, 0), robe_white)
	
	# Torso tunic
	visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_white)
	
	# Symmetrical gold sashes
	visual_component.call("create_box", parent, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.72, 0), gold_trim)
	visual_component.call("create_box", parent, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.35, 0), gold_trim)


func _build_folded_arms(visual_component: Object, parent: Node3D) -> void:
	var robe_white := Color(0.95, 0.95, 0.98)
	var gold_trim := Color(0.85, 0.65, 0.15)
	
	var arms := Node3D.new()
	var arms_node_name := "ArmsJoint"
	arms.name = arms_node_name
	arms.position = Vector3(0, 0.65, -0.23)
	parent.add_child(arms)
	visual_component.set("arms_node", arms)
	
	# Symmetrical folded sleeves representing Weaver meditation
	visual_component.call("create_box", arms, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_white * 0.9)
	visual_component.call("create_box", arms, Vector3(0.62, 0.04, 0.25), Vector3(0, 0, 0), gold_trim)


func _build_weaver_head_and_eyes(visual_component: Object, parent: Node3D) -> void:
	var skin_lilac := Color(0.72, 0.65, 0.78) # Faded lilac corrupted skin tone
	var static_pink := Color(0.95, 0.0, 0.95)   # Emissive static pink
	
	var head := Node3D.new()
	var head_node_name := "HumanHead"
	head.name = head_node_name
	head.position = Vector3(0, 1.05, 0)
	parent.add_child(head)
	visual_component.set("head_node", head)
	
	visual_component.call("create_box", head, Vector3(0.35, 0.52, 0.35), Vector3(0, 0.26, 0), skin_lilac)
	visual_component.call("create_box", head, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.06, -0.21), skin_lilac * 0.9)
	
	# Blinking-capable glowing purple eyes
	var l_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.08, 0.08, 0.02), Vector3(-0.09, 0.15, -0.18), static_pink) as MeshInstance3D
	var r_eye: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.08, 0.08, 0.02), Vector3(0.09, 0.15, -0.18), static_pink) as MeshInstance3D
	
	_apply_emissive_material(l_eye, static_pink, 2.5)
	_apply_emissive_material(r_eye, static_pink, 2.5)
	
	_build_levitating_static_crown(visual_component, head)


func _build_levitating_static_crown(visual_component: Object, head: Node3D) -> void:
	var gold_trim := Color(0.85, 0.65, 0.15)
	var static_pink := Color(0.95, 0.0, 0.95)
	
	# Floating gold halo
	visual_component.call("create_box", head, Vector3(0.42, 0.04, 0.42), Vector3(0, 0.56, 0), gold_trim)
	
	# Emissive static embers hovering around the crown points
	var ember_n: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.06, 0.12, 0.06), Vector3(0.0, 0.64, -0.18), static_pink) as MeshInstance3D
	var ember_e: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.06, 0.12, 0.06), Vector3(0.18, 0.64, 0.0), static_pink) as MeshInstance3D
	var ember_w: MeshInstance3D = visual_component.call("create_box", head, Vector3(0.06, 0.12, 0.06), Vector3(-0.18, 0.64, 0.0), static_pink) as MeshInstance3D
	
	_apply_emissive_material(ember_n, static_pink, 3.0)
	_apply_emissive_material(ember_e, static_pink, 3.0)
	_apply_emissive_material(ember_w, static_pink, 3.0)


func _apply_emissive_material(mesh_instance: MeshInstance3D, glow_color: Color, energy: float) -> void:
	if not is_instance_valid(mesh_instance):
		return
		
	var mat := mesh_instance.material_override as StandardMaterial3D
	if is_instance_valid(mat):
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = energy
		mat.roughness = 0.1


func get_collision_box_size() -> Vector3:
	return Vector3(0.6, 1.8, 0.6)


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.9, 0.0)
