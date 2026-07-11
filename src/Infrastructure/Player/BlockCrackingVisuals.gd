# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/BlockCrackingVisuals.gd
# Description: Infrastructure Component managing progressive block cracking 
#              visual overlays and texture preloading.
#              Decouples all progressive damage rendering from VoxelInteractionComponent (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BlockCrackingVisuals
extends Node3D

var _cracking_mesh: MeshInstance3D
var _cracking_textures: Array[Texture2D] = []


func _ready() -> void:
	name = "BlockCrackingVisuals"
	_preload_cracking_textures()
	_setup_cracking_mesh_overlay()


## Updates the position and texture of the cracking mesh overlay based on target damage ratios
func update_cracking_overlay(coord: Vector3i, ratio: float) -> void:
	if ratio <= 0.01:
		hide_cracking_overlay()
		return
		
	if is_instance_valid(_cracking_mesh):
		# Float the box exactly centered at the mined coordinate
		_cracking_mesh.global_position = Vector3(coord) + Vector3(0.5, 0.5, 0.5)
		_cracking_mesh.visible = true
		
		# Map [0.0 - 1.0] ratio to the 4 progressive cracking texture indices [0 - 3]
		var tex_index := clampi(floori(ratio * 4.0), 0, 3)
		
		var mat: StandardMaterial3D = _cracking_mesh.material_override as StandardMaterial3D
		if is_instance_valid(mat) and _cracking_textures.size() > tex_index:
			mat.albedo_texture = _cracking_textures[tex_index]


## Completely hides the visual cracking overlay
func hide_cracking_overlay() -> void:
	if is_instance_valid(_cracking_mesh):
		_cracking_mesh.visible = false


func _preload_cracking_textures() -> void:
	_cracking_textures.clear()
	for i: int in range(4):
		var path := "res://assets/textures/cracks_%d.png" % i
		if ResourceLoader.exists(path):
			_cracking_textures.append(load(path) as Texture2D)
		else:
			# Fallback placeholder texture
			_cracking_textures.append(PlaceholderTexture2D.new())


func _setup_cracking_mesh_overlay() -> void:
	_cracking_mesh = MeshInstance3D.new()
	_cracking_mesh.name = "VisualCrackingOverlay"
	
	var box_mesh := BoxMesh.new()
	# Scale slightly larger than 1x1x1 to prevent Z-fighting and Z-clipping artifacts
	box_mesh.size = Vector3(1.004, 1.004, 1.004)
	_cracking_mesh.mesh = box_mesh
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Highly performant, zero shadow cost
	
	_cracking_mesh.material_override = mat
	_cracking_mesh.visible = false
	
	add_child(_cracking_mesh)