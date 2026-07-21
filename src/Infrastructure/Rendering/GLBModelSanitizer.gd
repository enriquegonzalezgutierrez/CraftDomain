# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/GLBModelSanitizer.gd
# Description: Infrastructure Static Utility responsible for sanitizing 
#              imported 3D models (GLB/FBX). Removes extraneous nodes, 
#              strips tangent-requiring features, duplicates mesh resources,
#              and injects material fallbacks to eliminate Vulkan RD null-material
#              errors globally.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates 3D model sanitization.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GLBModelSanitizer
extends RefCounted


## Public API: Recursively prunes extraneous nodes and sanitizes materials.
static func sanitize_model(model_node: Node) -> void:
	if not is_instance_valid(model_node):
		return

	_prune_extraneous_nodes(model_node)
	_register_glb_materials(model_node)


## Recursively locates and frees extraneous camera, light, and collision nodes
static func _prune_extraneous_nodes(node: Node) -> void:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var is_extraneous := (
			"Camera" in child.name or 
			"Light" in child.name or 
			child is CollisionShape3D or 
			child is CollisionObject3D
		)
		
		if is_extraneous:
			child.free()
		else:
			_prune_extraneous_nodes(child)


## Recursively duplicates and sanitizes materials across ALL mesh surfaces
static func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		_sanitize_mesh_instance_surfaces(node as MeshInstance3D)

	for child: Node in node.get_children():
		_register_glb_materials(child)


static func _sanitize_mesh_instance_surfaces(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
		
	# VULKAN CLEANUP FIX: Duplicate the mesh resource to isolate material changes
	var mesh: Mesh = mesh_instance.mesh.duplicate() as Mesh
	mesh_instance.mesh = mesh
	
	for i: int in range(mesh.get_surface_count()):
		_sanitize_single_surface_material(mesh_instance, mesh, i)


static func _sanitize_single_surface_material(mesh_instance: MeshInstance3D, mesh: Mesh, surface_index: int) -> void:
	var mat: Material = mesh_instance.get_active_material(surface_index)
	if mat == null:
		mat = mesh.surface_get_material(surface_index)

	if mat is BaseMaterial3D:
		var new_mat := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		new_mat.normal_enabled = false
		new_mat.anisotropy_enabled = false
		new_mat.clearcoat_enabled = false
		new_mat.heightmap_enabled = false
		mesh_instance.set_surface_override_material(surface_index, new_mat)
	else:
		# VULKAN SAFEGUARD: Assign a solid default material if surface lacks one
		var fallback_mat := StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.8, 0.8, 0.8)
		fallback_mat.roughness = 0.8
		mesh_instance.set_surface_override_material(surface_index, fallback_mat)
