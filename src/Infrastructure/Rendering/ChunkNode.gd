# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkNode.gd
# Description: Infrastructure Rendering Node representing a single 3D Chunk.
#              Manages MultiMesh instances, custom geometry, and LOD transitions.
#              Delegates material PBR compilation to VoxelMaterialFactory (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data
var chunk: Chunk

var _collision_body: StaticBody3D
var _multimeshes: Dictionary = {} # block_id (int) -> Node

static var _shared_box_mesh: BoxMesh


func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	position = Vector3(chunk.position * Chunk.SIZE)


static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3(1.002, 1.002, 1.002) 
	return _shared_box_mesh


## Updates Level-of-Detail materials across all sub-meshes polymorphically
func update_lod_materials(is_distant: bool) -> void:
	for b_id: int in _multimeshes.keys():
		var node := _multimeshes[b_id] as Node
		if node is GeometryInstance3D:
			var mat := VoxelMaterialFactory.get_material(b_id, is_distant)
			if mat != null:
				(node as GeometryInstance3D).material_override = mat


## Public API: Configures or recycles multimesh segments and physics bodies
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_custom_meshes: Dictionary = {}, p_is_distant: bool = false) -> void:
	var active_ids: Dictionary = {}
	
	# 1. Update/Recycle MultiMeshes
	for b_id: int in p_multimesh_data.keys():
		var bulk_array: PackedFloat32Array = p_multimesh_data[b_id]
		var count := int(bulk_array.size() / 12.0)
		if count == 0: continue
		active_ids[b_id] = true
		_ensure_multimesh_instance(b_id, count, bulk_array, p_is_distant)

	# 2. Update Custom Meshes (Liquids/Slabs)
	for b_id: int in p_custom_meshes.keys():
		var mesh := p_custom_meshes[b_id] as ArrayMesh
		if mesh == null: continue
		active_ids[b_id] = true
		_ensure_mesh_instance(b_id, mesh, p_is_distant)

	# 3. Clean-up inactive segments
	var registered_keys := _multimeshes.keys()
	for b_id: int in registered_keys:
		if not active_ids.has(b_id):
			var node := _multimeshes[b_id] as Node
			if is_instance_valid(node):
				node.queue_free() 
			_multimeshes.erase(b_id)

	_update_collision(p_collision_body)


func has_collision_body() -> bool:
	return is_instance_valid(_collision_body)


func set_collision_body(body: StaticBody3D) -> void:
	_update_collision(body)


func _ensure_multimesh_instance(b_id: int, count: int, buffer: PackedFloat32Array, is_distant: bool) -> void:
	var mm_inst: MultiMeshInstance3D
	
	if _multimeshes.has(b_id) and is_instance_valid(_multimeshes[b_id]) and _multimeshes[b_id] is MultiMeshInstance3D:
		mm_inst = _multimeshes[b_id] as MultiMeshInstance3D
	else:
		mm_inst = MultiMeshInstance3D.new()
		add_child(mm_inst)
		_multimeshes[b_id] = mm_inst
		
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _get_shared_box_mesh()
	mm.instance_count = count
	mm.buffer = buffer
	mm_inst.multimesh = mm
	
	var mat := VoxelMaterialFactory.get_material(b_id, is_distant)
	if mat != null:
		mm_inst.material_override = mat
	mm_inst.visible = true


func _ensure_mesh_instance(b_id: int, mesh: ArrayMesh, is_distant: bool) -> void:
	var mi: MeshInstance3D
	
	if _multimeshes.has(b_id) and is_instance_valid(_multimeshes[b_id]) and _multimeshes[b_id] is MeshInstance3D:
		mi = _multimeshes[b_id] as MeshInstance3D
	else:
		mi = MeshInstance3D.new()
		add_child(mi)
		_multimeshes[b_id] = mi
		
	mi.mesh = mesh
	var mat := VoxelMaterialFactory.get_material(b_id, is_distant)
	if mat != null:
		mi.material_override = mat
	mi.visible = true


func _update_collision(new_body: StaticBody3D) -> void:
	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
	_collision_body = new_body
	if is_instance_valid(_collision_body):
		add_child(_collision_body)
