# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/EntityDeathVisuals.gd
# Description: Infrastructure presentation handler executing spatial dissolve 
#              shader transitions and unshaded death particles for dying entities.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityDeathVisuals
extends RefCounted

const DISSOLVE_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/spatial_dissolve.gdshader"


## Executes shader dissolve or fallback scale tween and frees the host entity
static func play_death_effect(host: CharacterBody3D, visual_root: Node3D) -> void:
	var shader := load(DISSOLVE_SHADER_PATH) as Shader if ResourceLoader.exists(DISSOLVE_SHADER_PATH) else null
	if shader != null and is_instance_valid(visual_root):
		_execute_shader_dissolve_death(host, visual_root, shader)
	else:
		_execute_fallback_death_tween(host, visual_root)
		
	_spawn_death_particles(host)


static func _execute_shader_dissolve_death(host: CharacterBody3D, visual_root: Node3D, shader: Shader) -> void:
	var base_mat := ShaderMaterial.new()
	base_mat.shader = shader
	base_mat.set_shader_parameter("noise_tex", VoxelMaterialFactory._get_or_create_water_noise_a())
	
	_apply_dissolve_material_to_mesh_nodes(visual_root, base_mat)
	
	var death_tween := host.create_tween()
	death_tween.tween_method(_set_dissolve_progress_recursive.bind(visual_root), 0.0, 1.0, 0.65)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	death_tween.chain().tween_callback(host.queue_free)


static func _apply_dissolve_material_to_mesh_nodes(node: Node, shader_mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var orig_mat := mi.material_override as BaseMaterial3D
		if orig_mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			orig_mat = mi.mesh.surface_get_material(0) as BaseMaterial3D
			
		var instance_shader_mat := shader_mat.duplicate() as ShaderMaterial
		if is_instance_valid(orig_mat):
			instance_shader_mat.set_shader_parameter("base_albedo", orig_mat.albedo_color)
			if orig_mat.albedo_texture != null:
				instance_shader_mat.set_shader_parameter("albedo_texture", orig_mat.albedo_texture)
				
		mi.material_override = instance_shader_mat
		
	for child in node.get_children():
		_apply_dissolve_material_to_mesh_nodes(child, shader_mat)


static func _set_dissolve_progress_recursive(progress: float, root_node: Node) -> void:
	_update_node_dissolve_progress(root_node, progress)


static func _update_node_dissolve_progress(node: Node, progress: float) -> void:
	if node is MeshInstance3D:
		var sm := (node as MeshInstance3D).material_override as ShaderMaterial
		if is_instance_valid(sm):
			sm.set_shader_parameter("dissolve_progress", progress)
			
	for child in node.get_children():
		_update_node_dissolve_progress(child, progress)


static func _execute_fallback_death_tween(host: CharacterBody3D, visual_root: Node3D) -> void:
	var death_tween := host.create_tween().set_parallel(true)
	if is_instance_valid(visual_root):
		death_tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
	death_tween.chain().tween_callback(host.queue_free)


static func _spawn_death_particles(host: CharacterBody3D) -> void:
	var particles := CPUParticles3D.new()
	_configure_death_particle_properties(particles)
	_attach_death_particle_mesh(particles)
	
	particles.finished.connect(particles.queue_free)
	var world_node := host.get_parent()
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = host.global_position + Vector3(0.0, 0.5, 0.0)
		particles.emitting = true


static func _configure_death_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, 2.0, 0.0)


static func _attach_death_particle_mesh(particles: CPUParticles3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mesh.material = mat
	particles.mesh = mesh
