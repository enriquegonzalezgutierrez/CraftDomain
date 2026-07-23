# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# Description: Infrastructure Rendering Service evaluating chunk voxel grids,
#              applying high-performance 2D Greedy Meshing, and packing transforms.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkVisualBuilder
extends RefCounted

const CHUNK_MASK: int = 15
const SLICE_SIZE: int = 16

class VoxelRenderBuffer:
	var data: PackedFloat32Array
	var pointer: int = 0
	
	func _init() -> void:
		data = PackedFloat32Array()
		data.resize(4096 * 12)
		
	func push_transform(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float) -> void:
		var p := pointer
		data[p] = sx;  data[p+1] = 0.0; data[p+2] = 0.0; data[p+3] = cx;
		data[p+4] = 0.0; data[p+5] = sy;  data[p+6] = 0.0; data[p+7] = cy;
		data[p+8] = 0.0; data[p+9] = 0.0; data[p+10] = sz;  data[p+11] = cz;
		pointer += 12
		
	func commit() -> PackedFloat32Array:
		return data.slice(0, pointer)


## Extracts, merges and compiles raw chunk voxel data into optimized rendering arrays.
static func extract_render_data(chunk: Chunk, world_state: WorldState, build_collision: bool = true) -> Dictionary:
	var render_buffers: Dictionary = {}
	var collision_vertices := PackedVector3Array()
	
	_execute_greedy_slice_sweep(chunk, world_state, build_collision, render_buffers, collision_vertices)
	return {
		"multimesh": _pack_multimesh_float_arrays(render_buffers),
		"collision_vertices": collision_vertices
	}


static func _execute_greedy_slice_sweep(chunk: Chunk, world_state: WorldState, build_collision: bool, render_buffers: Dictionary, collision_vertices: PackedVector3Array) -> void:
	var neighbors := _gather_boundary_neighbors(chunk, world_state)
	
	# Sweep horizontally along Y layers
	for y in range(Chunk.SIZE):
		var slice_ids := PackedInt32Array()
		var visibility_mask := PackedByteArray()
		slice_ids.resize(SLICE_SIZE * SLICE_SIZE)
		visibility_mask.resize(SLICE_SIZE * SLICE_SIZE)
		
		_build_slice_exposure_maps(chunk, y, neighbors, slice_ids, visibility_mask)
		var merged_quads := VoxelGreedyMesherSolver.solve_slice(slice_ids, visibility_mask)
		_process_merged_quads(merged_quads, y, build_collision, render_buffers, collision_vertices)


static func _gather_boundary_neighbors(chunk: Chunk, world_state: WorldState) -> Dictionary:
	return {
		Vector3i(1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(1, 0, 0)),
		Vector3i(-1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(-1, 0, 0)),
		Vector3i(0, 1, 0): world_state.get_chunk(chunk.position + Vector3i(0, 1, 0)),
		Vector3i(0, -1, 0): world_state.get_chunk(chunk.position + Vector3i(0, -1, 0)),
		Vector3i(0, 0, 1): world_state.get_chunk(chunk.position + Vector3i(0, 0, 1)),
		Vector3i(0, 0, -1): world_state.get_chunk(chunk.position + Vector3i(0, 0, -1))
	}


static func _build_slice_exposure_maps(chunk: Chunk, y: int, neighbors: Dictionary, slice_ids: PackedInt32Array, visibility_mask: PackedByteArray) -> void:
	for z in range(Chunk.SIZE):
		for x in range(Chunk.SIZE):
			var idx := x + Chunk.SIZE * z
			var b_id := chunk.get_block(x, y, z)
			slice_ids[idx] = b_id
			visibility_mask[idx] = 1 if _is_voxel_exposed(chunk, Vector3i(x, y, z), neighbors) else 0


static func _is_voxel_exposed(chunk: Chunk, local_pos: Vector3i, neighbors: Dictionary) -> bool:
	var block_type := chunk.get_block(local_pos.x, local_pos.y, local_pos.z)
	if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
		return false
		
	var def := BlockLibrary.get_definition(block_type)
	if not def.geometry is FullCubeGeometry:
		return false
		
	for dir: Vector3i in ChunkMesher.DIRECTIONS:
		if _is_face_visible(chunk, local_pos, dir, neighbors):
			return true
	return false


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


static func _process_merged_quads(quads: Array[VoxelGreedyMesherSolver.MergedQuad], y: int, build_col: bool, buffers: Dictionary, col_verts: PackedVector3Array) -> void:
	for q in quads:
		var cx := float(q.start_x) + float(q.width) / 2.0
		var cy := float(y) + 0.5
		var cz := float(q.start_z) + float(q.height) / 2.0
		
		_register_multimesh_transform(buffers, q.block_id, cx, cy, cz, float(q.width), 1.0, float(q.height))
		
		if build_col:
			_append_merged_collision_box(q, y, col_verts)


static func _register_multimesh_transform(buffers: Dictionary, b_id: int, cx: float, cy: float, cz: float, sx: float, sy: float, sz: float) -> void:
	var buffer: VoxelRenderBuffer
	if not buffers.has(b_id):
		buffer = VoxelRenderBuffer.new()
		buffers[b_id] = buffer
	else:
		buffer = buffers[b_id] as VoxelRenderBuffer
		
	buffer.push_transform(cx, cy, cz, sx, sy, sz)


static func _append_merged_collision_box(q: VoxelGreedyMesherSolver.MergedQuad, y: int, col_verts: PackedVector3Array) -> void:
	var x0 := float(q.start_x)
	var x1 := float(q.start_x + q.width)
	var y0 := float(y)
	var y1 := float(y + 1)
	var z0 := float(q.start_z)
	var z1 := float(q.start_z + q.height)
	
	_add_collision_face(col_verts, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)) # TOP
	_add_collision_face(col_verts, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)) # BOTTOM
	_add_collision_face(col_verts, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0)) # RIGHT
	_add_collision_face(col_verts, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1)) # LEFT
	_add_collision_face(col_verts, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1)) # FRONT
	_add_collision_face(col_verts, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0)) # BACK


static func _add_collision_face(col_verts: PackedVector3Array, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	col_verts.append(v2)
	col_verts.append(v1)
	col_verts.append(v0)
	
	col_verts.append(v3)
	col_verts.append(v2)
	col_verts.append(v0)


static func _pack_multimesh_float_arrays(render_buffers: Dictionary) -> Dictionary:
	var final_multimesh_data: Dictionary = {}
	for b_type: BlockType.Type in render_buffers.keys():
		var buffer := render_buffers[b_type] as VoxelRenderBuffer
		final_multimesh_data[b_type] = buffer.commit()
	return final_multimesh_data
