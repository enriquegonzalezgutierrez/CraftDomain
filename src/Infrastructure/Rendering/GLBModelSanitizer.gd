# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/GLBModelSanitizer.gd
# Description: Infrastructure Static Utility responsible ONLY for sanitizing 
#              imported 3D models (GLB/FBX). Removes extraneous Blender nodes 
#              (Cameras/Lights) and strips tangent-requiring PBR features to 
#              prevent C++ engine warnings and boost performance.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates model manipulation math.
# - Don't Repeat Yourself (DRY): Centralizes logic previously copy-pasted 
#   across 25+ entity scripts.
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


## Recursively locates and frees extraneous camera and light nodes
static func _prune_extraneous_nodes(node: Node) -> void:
	# Iterate backwards when freeing children to preserve array indexing
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)


## Recursively duplicates and sanitizes materials across ALL mesh surfaces (Tangent Shield)
static func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Multi-Surface Sweep: Sanitize every material index on the mesh
		for i: int in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
				
			if mat is BaseMaterial3D:
				# Explicit casting to prevent static analyzer type inference errors
				var new_mat := mat.duplicate() as BaseMaterial3D
				
				# TANGENT WARNING SHIELD: Disables features that require tangent arrays
				new_mat.normal_enabled = false
				new_mat.anisotropy_enabled = false
				new_mat.clearcoat_enabled = false
				new_mat.heightmap_enabled = false
				
				node.set_surface_override_material(i, new_mat)
			
	for child: Node in node.get_children():
		_register_glb_materials(child)
