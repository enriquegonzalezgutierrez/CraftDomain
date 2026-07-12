# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# Description: Infrastructure Rendering Service responsible for evaluating raw
#              chunk data, applying occlusion culling, and compiling transformation
#              data for rendering and physics. Decomposed into short methods (SRP).
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


## Public API: Extracts, packages, and formats visual MultiMeshes and collision shapes
static func extract_render_data(chunk: Chunk, world_state: WorldState, build_collision: bool = true) -> Dictionary:
	var render_data: Dictionary = {}
	var collision_vertices := PackedVector3Array()
	var neighbors := _gather_boundary_neighbors(chunk, world_state)
	
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				_evaluate_voxel_face_occlusion(
					chunk, 
					Vector3i(x, y, z), 
					neighbors, 
					build_collision, 
					render_data, 
					collision_vertices
				)
						
	return {
		"multimesh": _pack_multimesh_float_arrays(render_data),
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


static func _evaluate_voxel_face_occlusion(chunk: Chunk, local_pos: Vector3i, neighbors: Dictionary, build_collision: bool, render_data: Dictionary, collision_vertices: PackedVector3Array) -> void:
	var block_type: BlockType.Type = chunk.get_block(local_pos.x, local_pos.y, local_pos.z)
	if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
		return
		
	var def := BlockLibrary.get_definition(block_type)
	var float_pos := Vector3(local_pos)
	var is_exposed := false
	
	for dir: Vector3i in DIRECTIONS:
		var neighbor_type := _get_neighbor_block_type(chunk, local_pos, dir, neighbors)
		var neighbor_def := BlockLibrary.get_definition(neighbor_type)
		
		var face_visible: bool = (
			neighbor_type == BlockType.Type.AIR or 
			BlockType.is_transparent(neighbor_type) or 
			not neighbor_def.geometry.is_face_opaque(-dir)
		)
		
		if face_visible:
			is_exposed = true
			if build_collision and BlockType.is_solid(block_type):
				_append_collision_face_vertices(def, dir, float_pos, collision_vertices)
				
	if is_exposed and def.geometry is FullCubeGeometry:
		_register_multimesh_transform(render_data, block_type, float_pos)


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


static func _register_multimesh_transform(render_data: Dictionary, block_type: BlockType.Type, float_pos: Vector3) -> void:
	var t := Transform3D(Basis(), float_pos + Vector3(0.5, 0.5, 0.5))
	if not render_data.has(block_type):
		render_data[block_type] = []
	render_data[block_type].append(t)


static func _pack_multimesh_float_arrays(render_data: Dictionary) -> Dictionary:
	var final_multimesh_data: Dictionary = {}
	for b_type: BlockType.Type in render_data.keys():
		var transforms: Array = render_data[b_type] as Array
		var count := transforms.size()
		
		var bulk_array := PackedFloat32Array()
		bulk_array.resize(count * 12)
		
		for i: int in range(count):
			var t: Transform3D = transforms[i] as Transform3D
			var offset := i * 12
			bulk_array[offset + 0] = t.basis.x.x; bulk_array[offset + 1] = t.basis.y.x; bulk_array[offset + 2] = t.basis.z.x
			bulk_array[offset + 3] = t.origin.x; bulk_array[offset + 4] = t.basis.x.y; bulk_array[offset + 5] = t.basis.y.y
			bulk_array[offset + 6] = t.basis.z.y; bulk_array[offset + 7] = t.origin.y; bulk_array[offset + 8] = t.basis.x.z
			bulk_array[offset + 9] = t.basis.y.z; bulk_array[offset + 10] = t.basis.z.z; bulk_array[offset + 11] = t.origin.z
			
		final_multimesh_data[b_type] = bulk_array
	return final_multimesh_data
