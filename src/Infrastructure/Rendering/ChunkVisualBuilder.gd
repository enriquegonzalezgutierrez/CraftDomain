# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# Description: Infrastructure Rendering Service responsible for evaluating raw
#              chunk data, applying occlusion culling, and compiling transformation
#              data for rendering and physics.
#              PERFORMANCE UPGRADE: Implemented Zero-Allocation Buffers to 
#              eliminate Garbage Collection (GC) stutters during mesh generation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkVisualBuilder
extends RefCounted

const CHUNK_MASK: int = 15 

static var DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # UP
	Vector3i(0, -1, 0),  # DOWN
	Vector3i(1, 0, 0),   # RIGHT
	Vector3i(-1, 0, 0),  # LEFT
	Vector3i(0, 0, 1),   # FRONT
	Vector3i(0, 0, -1)   # BACK
]

## Inner class for zero-allocation memory buffering (Eliminates GC stalls)
class VoxelRenderBuffer:
	var data: PackedFloat32Array
	var pointer: int = 0
	
	func _init() -> void:
		data = PackedFloat32Array()
		data.resize(4096 * 12) # Maximum theoretical limit of blocks per chunk
		
	func push_transform(cx: float, cy: float, cz: float) -> void:
		var p := pointer
		# Hardcoded basis scaling identity matrix with position offsets
		data[p] = 1.0; data[p+1] = 0.0; data[p+2] = 0.0; data[p+3] = cx;
		data[p+4] = 0.0; data[p+5] = 1.0; data[p+6] = 0.0; data[p+7] = cy;
		data[p+8] = 0.0; data[p+9] = 0.0; data[p+10] = 1.0; data[p+11] = cz;
		pointer += 12
		
	func commit() -> PackedFloat32Array:
		return data.slice(0, pointer)


## Public API: Extracts, packages, and formats visual MultiMeshes and collision shapes
static func extract_render_data(chunk: Chunk, world_state: WorldState, build_collision: bool = true) -> Dictionary:
	var render_buffers: Dictionary = {}
	var collision_vertices := PackedVector3Array()
	var neighbors := _gather_boundary_neighbors(chunk, world_state)
	
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				_evaluate_voxel_face_occlusion(
					chunk, Vector3i(x, y, z), neighbors, 
					build_collision, render_buffers, collision_vertices
				)
						
	return {
		"multimesh": _pack_multimesh_float_arrays(render_buffers),
		"collision_vertices": collision_vertices
	}


static func _gather_boundary_neighbors(chunk: Chunk, world_state: WorldState) -> Dictionary:
	return {
		Vector3i(1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(1, 0, 0)),
		Vector3i(-1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(-1, 0, 0)),
		Vector3i(0, 1, 0): world_state.get_chunk(chunk.position + Vector3i(0, 1, 0)),
		Vector3i(0, -1, 0): world_state.get_chunk(chunk.position + Vector3i(0, -1, 0)),
		Vector3i(0, 0, 1): world_state.get_chunk(chunk.position + Vector3i(0, 0, 1)),
		Vector3i(0, 0, -1): world_state.get_chunk(chunk.position + Vector3i(0, 0, -1))
	}


static func _evaluate_voxel_face_occlusion(chunk: Chunk, local_pos: Vector3i, neighbors: Dictionary, build_collision: bool, render_buffers: Dictionary, collision_vertices: PackedVector3Array) -> void:
	var block_type: BlockType.Type = chunk.get_block(local_pos.x, local_pos.y, local_pos.z)
	if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
		return
		
	var def := BlockLibrary.get_definition(block_type)
	var float_pos := Vector3(local_pos)
	var is_exposed := false
	
	for dir: Vector3i in DIRECTIONS:
		var is_face_exposed := _is_face_visible(chunk, local_pos, dir, neighbors)
		
		if is_face_exposed:
			is_exposed = true
			if build_collision and def.is_solid:
				_append_collision_face_vertices(def, dir, float_pos, collision_vertices)
				
	if is_exposed and def.geometry is FullCubeGeometry:
		_register_multimesh_transform(render_buffers, block_type, float_pos)


static func _is_face_visible(chunk: Chunk, local_pos: Vector3i, dir: Vector3i, neighbors: Dictionary) -> bool:
	var neighbor_type := _get_neighbor_block_type(chunk, local_pos, dir, neighbors)
	if neighbor_type == BlockType.Type.AIR:
		return true
		
	var neighbor_def := BlockLibrary.get_definition(neighbor_type)
	return neighbor_def.is_transparent or not neighbor_def.geometry.is_face_opaque(-dir)


static func _get_neighbor_block_type(chunk: Chunk, local_pos: Vector3i, dir: Vector3i, neighbors: Dictionary) -> BlockType.Type:
	var nx := local_pos.x + dir.x
	var ny := local_pos.y + dir.y
	var nz := local_pos.z + dir.z
	
	if nx >= 0 and nx < Chunk.SIZE and ny >= 0 and ny < Chunk.SIZE and nz >= 0 and nz < Chunk.SIZE:
		return chunk.get_block(nx, ny, nz)
		
	var n_chunk: Chunk = neighbors[dir]
	if n_chunk != null:
		return n_chunk.get_block(nx & CHUNK_MASK, ny & CHUNK_MASK, nz & CHUNK_MASK)
		
	return BlockType.Type.AIR


static func _append_collision_face_vertices(def: BlockDefinition, dir: Vector3i, float_pos: Vector3, collision_vertices: PackedVector3Array) -> void:
	var face_verts := def.geometry.get_face_collision_vertices(dir)
	if face_verts.size() == 4:
		var v0 := float_pos + face_verts[0]
		var v1 := float_pos + face_verts[1]
		var v2 := float_pos + face_verts[2]
		var v3 := float_pos + face_verts[3]
		
		collision_vertices.append(v2)
		collision_vertices.append(v1)
		collision_vertices.append(v0)
		
		collision_vertices.append(v3)
		collision_vertices.append(v2)
		collision_vertices.append(v0)


static func _register_multimesh_transform(render_buffers: Dictionary, block_type: BlockType.Type, float_pos: Vector3) -> void:
	var buffer: VoxelRenderBuffer
	if not render_buffers.has(block_type):
		buffer = VoxelRenderBuffer.new()
		render_buffers[block_type] = buffer
	else:
		buffer = render_buffers[block_type] as VoxelRenderBuffer
		
	buffer.push_transform(float_pos.x + 0.5, float_pos.y + 0.5, float_pos.z + 0.5)


static func _pack_multimesh_float_arrays(render_buffers: Dictionary) -> Dictionary:
	var final_multimesh_data: Dictionary = {}
	for b_type: BlockType.Type in render_buffers.keys():
		var buffer := render_buffers[b_type] as VoxelRenderBuffer
		final_multimesh_data[b_type] = buffer.commit()
	return final_multimesh_data
