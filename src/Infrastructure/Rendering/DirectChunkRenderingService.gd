# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/DirectChunkRenderingService.gd
# Description: Infrastructure Service executing Direct Server-Side Architecture.
#              Bypasses the SceneTree by communicating directly with Godot's
#              RenderingServer and PhysicsServer3D via RIDs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DirectChunkRenderingService
extends RefCounted

class ChunkRIDRecord:
	var multimesh_rids: Array[RID] = []
	var instance_rids: Array[RID] = []
	var instance_block_ids: Array[int] = []
	var custom_meshes: Array[ArrayMesh] = []
	var physics_body_rid: RID = RID()
	var collision_shape_ref: ConcavePolygonShape3D = null

var controller: Node3D
var _world_scenario: RID
var _world_space: RID
var _active_chunks: Dictionary = {}

static var _shared_box_mesh: BoxMesh


func _init(p_controller: Node3D, scenario: RID, space: RID) -> void:
	controller = p_controller
	_world_scenario = scenario
	_world_space = space
	
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3.ONE


## Allocates server-side MultiMeshes, custom geometry instances, and physics bodies.
func allocate_chunk_visuals(chunk_pos: Vector3i, multimesh_data: Dictionary, custom_meshes: Dictionary, collision_shape: ConcavePolygonShape3D, is_distant: bool) -> void:
	free_chunk(chunk_pos)
	
	if not _world_scenario.is_valid() and is_instance_valid(controller):
		_world_scenario = controller.get_world_3d().scenario
		_world_space = controller.get_world_3d().space
	
	var record := ChunkRIDRecord.new()
	var transform := Transform3D(Basis(), Vector3(chunk_pos * Chunk.SIZE))
	
	_allocate_multimeshes(record, transform, multimesh_data, is_distant)
	_allocate_custom_meshes(record, transform, custom_meshes, is_distant)
	
	if collision_shape != null:
		_allocate_physics_body(record, transform, collision_shape)
		
	_active_chunks[chunk_pos] = record


## Toggles the low-level rendering server visibility for a specific chunk (LSP/OCP).
func set_chunk_visible(chunk_pos: Vector3i, visible: bool) -> void:
	if not _active_chunks.has(chunk_pos):
		return
		
	var record: ChunkRIDRecord = _active_chunks[chunk_pos] as ChunkRIDRecord
	for inst_rid: RID in record.instance_rids:
		if inst_rid.is_valid():
			RenderingServer.instance_set_visible(inst_rid, visible)


## Safe Teardown Purge: Detaches instances from scenario before freeing RIDs.
func free_chunk(chunk_pos: Vector3i) -> void:
	if not _active_chunks.has(chunk_pos):
		return
		
	var record: ChunkRIDRecord = _active_chunks[chunk_pos] as ChunkRIDRecord
	_detach_and_free_instances(record)
	_detach_and_free_physics(record)
	_active_chunks.erase(chunk_pos)


func _detach_and_free_instances(record: ChunkRIDRecord) -> void:
	for inst_rid: RID in record.instance_rids:
		if inst_rid.is_valid():
			RenderingServer.instance_set_scenario(inst_rid, RID())
			RenderingServer.instance_geometry_set_material_override(inst_rid, RID())
			RenderingServer.free_rid(inst_rid)
			
	for mm_rid: RID in record.multimesh_rids:
		if mm_rid.is_valid():
			RenderingServer.free_rid(mm_rid)


func _detach_and_free_physics(record: ChunkRIDRecord) -> void:
	if record.physics_body_rid.is_valid():
		PhysicsServer3D.body_set_space(record.physics_body_rid, RID())
		PhysicsServer3D.free_rid(record.physics_body_rid)


func _allocate_multimeshes(record: ChunkRIDRecord, transform: Transform3D, multimesh_data: Dictionary, is_distant: bool) -> void:
	for b_id: int in multimesh_data.keys():
		var buffer: PackedFloat32Array = multimesh_data[b_id] as PackedFloat32Array
		var count := int(buffer.size() / 12.0)
		if count == 0: continue
			
		var mm_rid := RenderingServer.multimesh_create()
		RenderingServer.multimesh_set_mesh(mm_rid, _shared_box_mesh.get_rid())
		RenderingServer.multimesh_allocate_data(mm_rid, count, RenderingServer.MULTIMESH_TRANSFORM_3D)
		RenderingServer.multimesh_set_buffer(mm_rid, buffer)
		
		var inst_rid := RenderingServer.instance_create()
		RenderingServer.instance_set_scenario(inst_rid, _world_scenario)
		RenderingServer.instance_set_transform(inst_rid, transform)
		
		_apply_material_to_instance(inst_rid, b_id, is_distant)
		RenderingServer.instance_set_base(inst_rid, mm_rid)
		
		record.multimesh_rids.append(mm_rid)
		record.instance_rids.append(inst_rid)
		record.instance_block_ids.append(b_id)


func _allocate_custom_meshes(record: ChunkRIDRecord, transform: Transform3D, custom_meshes: Dictionary, is_distant: bool) -> void:
	for b_id: int in custom_meshes.keys():
		var mesh: ArrayMesh = custom_meshes[b_id] as ArrayMesh
		if mesh == null: continue
			
		var mat: Material = VoxelMaterialFactory.get_material(b_id, is_distant)
		if is_instance_valid(mat) and mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, mat)
			
		var inst_rid := RenderingServer.instance_create()
		RenderingServer.instance_set_scenario(inst_rid, _world_scenario)
		RenderingServer.instance_set_transform(inst_rid, transform)
		
		if is_instance_valid(mat):
			RenderingServer.instance_geometry_set_material_override(inst_rid, mat.get_rid())
			
		RenderingServer.instance_set_base(inst_rid, mesh.get_rid())
		record.instance_rids.append(inst_rid)
		record.instance_block_ids.append(b_id)
		record.custom_meshes.append(mesh)


func _allocate_physics_body(record: ChunkRIDRecord, transform: Transform3D, shape: ConcavePolygonShape3D) -> void:
	var body_rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body_rid, _world_space)
	PhysicsServer3D.body_add_shape(body_rid, shape.get_rid())
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)
	
	PhysicsServer3D.body_set_param(body_rid, PhysicsServer3D.BODY_PARAM_FRICTION, 1.0)
	PhysicsServer3D.body_set_param(body_rid, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.0)
	PhysicsServer3D.body_set_collision_layer(body_rid, 1)
	PhysicsServer3D.body_set_collision_mask(body_rid, 1)
	
	record.physics_body_rid = body_rid
	record.collision_shape_ref = shape


func _apply_material_to_instance(inst_rid: RID, b_id: int, is_distant: bool) -> void:
	var mat: Material = VoxelMaterialFactory.get_material(b_id, is_distant)
	if is_instance_valid(mat) and inst_rid.is_valid():
		RenderingServer.instance_geometry_set_material_override(inst_rid, mat.get_rid())


func update_lod_materials(chunk_pos: Vector3i, is_distant: bool) -> void:
	if not _active_chunks.has(chunk_pos): return
		
	var record: ChunkRIDRecord = _active_chunks[chunk_pos] as ChunkRIDRecord
	var multimesh_count := record.multimesh_rids.size()
	
	for i in range(record.instance_rids.size()):
		var inst_rid: RID = record.instance_rids[i]
		if not inst_rid.is_valid(): continue
			
		var b_id: int = record.instance_block_ids[i]
		_apply_material_to_instance(inst_rid, b_id, is_distant)
		
		if i >= multimesh_count:
			_apply_custom_mesh_lod(record, i - multimesh_count, b_id, is_distant)


func _apply_custom_mesh_lod(record: ChunkRIDRecord, custom_idx: int, b_id: int, is_distant: bool) -> void:
	if custom_idx >= 0 and custom_idx < record.custom_meshes.size():
		var mesh: ArrayMesh = record.custom_meshes[custom_idx]
		if is_instance_valid(mesh) and mesh.get_surface_count() > 0:
			var mat := VoxelMaterialFactory.get_material(b_id, is_distant)
			if is_instance_valid(mat):
				mesh.surface_set_material(0, mat)


func has_collision_body(chunk_pos: Vector3i) -> bool:
	if _active_chunks.has(chunk_pos):
		var record: ChunkRIDRecord = _active_chunks[chunk_pos] as ChunkRIDRecord
		return record.physics_body_rid.is_valid()
	return false


func clear_all() -> void:
	var keys := _active_chunks.keys()
	for pos: Vector3i in keys:
		free_chunk(pos)
