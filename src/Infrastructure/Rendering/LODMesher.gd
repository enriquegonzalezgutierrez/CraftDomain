# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/LODMesher.gd
# Description: Infrastructure Service responsible for down-sampling and decimating
#              distant 3D chunks block grids from 16^3 to 8x8x8 voxels.
#              PERFORMANCE UPGRADE: Implemented Zero-Allocation Buffers to 
#              prevent Transform3D instantiations and eliminate GC stutters.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LODMesher
extends RefCounted

const DECIMATED_SIZE: int = 8 # 8x8x8 down-sampled grid
const VOXEL_STEP: int = 2     # Group 2x2x2 blocks together

## Inner class for zero-allocation memory buffering (Eliminates GC stalls)
class VoxelLODRenderBuffer:
	var data: PackedFloat32Array
	var pointer: int = 0
	
	func _init() -> void:
		data = PackedFloat32Array()
		data.resize(512 * 12) # Maximum 8x8x8 = 512 decimated blocks
		
	func push_transform(cx: float, cy: float, cz: float) -> void:
		var p := pointer
		# Hardcoded basis scaling identity matrix (Scale x2.0) with position offsets
		data[p] = 2.0; data[p+1] = 0.0; data[p+2] = 0.0; data[p+3] = cx;
		data[p+4] = 0.0; data[p+5] = 2.0; data[p+6] = 0.0; data[p+7] = cy;
		data[p+8] = 0.0; data[p+9] = 0.0; data[p+10] = 2.0; data[p+11] = cz;
		pointer += 12
		
	func commit() -> PackedFloat32Array:
		return data.slice(0, pointer)


## Down-samples a 16x16x16 chunk blocks grid into an optimized 8x8x8 vertex mesh buffer.
static func generate_decimated_mesh_data(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var render_buffers: Dictionary = {}
	
	for rx: int in range(DECIMATED_SIZE):
		for ry: int in range(DECIMATED_SIZE):
			for rz: int in range(DECIMATED_SIZE):
				var resolved_type := _evaluate_voxel_subgrid_cluster(chunk, rx * VOXEL_STEP, ry * VOXEL_STEP, rz * VOXEL_STEP)
				
				if resolved_type != BlockType.Type.AIR:
					_compile_decimated_transforms(render_buffers, resolved_type, rx, ry, rz, chunk.position, world_state)
					
	return _pack_decimated_float_arrays(render_buffers)


## Evaluates the most frequent solid block type inside a 2x2x2 sub-grid coordinate group.
static func _evaluate_voxel_subgrid_cluster(chunk: Chunk, start_x: int, start_y: int, start_z: int) -> BlockType.Type:
	var type_histogram: Dictionary = {}
	var solid_count := 0
	
	for x: int in range(VOXEL_STEP):
		for y: int in range(VOXEL_STEP):
			for z: int in range(VOXEL_STEP):
				var block := chunk.get_block(start_x + x, start_y + y, start_z + z)
				if block != BlockType.Type.AIR and BlockType.is_solid(block):
					solid_count += 1
					type_histogram[block] = type_histogram.get(block, 0) + 1
					
	if solid_count < 4:
		return BlockType.Type.AIR
		
	return _find_most_frequent_block(type_histogram)


## Locates the block ID that occurs most frequently in the scanned sub-grid.
static func _find_most_frequent_block(histogram: Dictionary) -> BlockType.Type:
	var best_type := BlockType.Type.AIR
	var max_count := -1
	
	for block_id: int in histogram.keys():
		var count: int = histogram[block_id] as int
		if count > max_count:
			max_count = count
			best_type = block_id as BlockType.Type
			
	return best_type


## Injects the coordinates directly into the pre-allocated buffers.
static func _compile_decimated_transforms(render_buffers: Dictionary, type: BlockType.Type, rx: int, ry: int, rz: int, chunk_pos: Vector3i, world_state: WorldState) -> void:
	var is_visible := _check_decimated_voxel_exposure(rx, ry, rz, chunk_pos, world_state)
	if not is_visible:
		return
		
	var cx := float(rx * 2) + 1.0
	var cy := float(ry * 2) + 1.0
	var cz := float(rz * 2) + 1.0
	
	var buffer: VoxelLODRenderBuffer
	if not render_buffers.has(type):
		buffer = VoxelLODRenderBuffer.new()
		render_buffers[type] = buffer
	else:
		buffer = render_buffers[type] as VoxelLODRenderBuffer
		
	buffer.push_transform(cx, cy, cz)


## Evaluates adjacency to determine if a decimated face is exposed and should be drawn.
static func _check_decimated_voxel_exposure(rx: int, ry: int, rz: int, chunk_pos: Vector3i, world_state: WorldState) -> bool:
	if rx == 0 or rx == DECIMATED_SIZE - 1 or ry == 0 or ry == DECIMATED_SIZE - 1 or rz == 0 or rz == DECIMATED_SIZE - 1:
		return true
		
	var directions: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for dir: Vector3i in directions:
		var neighbor_coord := (chunk_pos * Chunk.SIZE) + Vector3i((rx + dir.x) * VOXEL_STEP, (ry + dir.y) * VOXEL_STEP, (rz + dir.z) * VOXEL_STEP)
		if world_state.get_block(neighbor_coord) == BlockType.Type.AIR:
			return true
			
	return false


## Flushes the pre-allocated buffers into standard format dictionaries.
static func _pack_decimated_float_arrays(render_buffers: Dictionary) -> Dictionary:
	var final_multimesh_data: Dictionary = {}
	for b_type: BlockType.Type in render_buffers.keys():
		var buffer := render_buffers[b_type] as VoxelLODRenderBuffer
		final_multimesh_data[b_type] = buffer.commit()
	return final_multimesh_data
