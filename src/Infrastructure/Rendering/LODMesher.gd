# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/LODMesher.gd
# Description: Infrastructure Service responsible for down-sampling and decimating
#              distant 3D chunks block grids from 16^3 to 8x8x8 voxels,
#              slashing vertex shading overhead by up to 87.5% on mobile GPUs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LODMesher
extends RefCounted

const DECIMATED_SIZE: int = 8 # 8x8x8 down-sampled grid
const VOXEL_STEP: int = 2     # Group 2x2x2 blocks together


## Down-samples a 16x16x16 chunk blocks grid into an optimized 8x8x8 vertex mesh buffer.
static func generate_decimated_mesh_data(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var render_data: Dictionary = {}
	
	# We iterate over the down-sampled grid
	for rx: int in range(DECIMATED_SIZE):
		for ry: int in range(DECIMATED_SIZE):
			for rz: int in range(DECIMATED_SIZE):
				var resolved_type := _evaluate_voxel_subgrid_cluster(chunk, rx * VOXEL_STEP, ry * VOXEL_STEP, rz * VOXEL_STEP)
				
				if resolved_type != BlockType.Type.AIR:
					_compile_decimated_transforms(render_data, resolved_type, rx, ry, rz, chunk.position, world_state)
					
	return _pack_decimated_float_arrays(render_data)


## Evaluates the most frequent solid block type inside a 2x2x2 sub-grid coordinate group.
static func _evaluate_voxel_subgrid_cluster(chunk: Chunk, start_x: int, start_y: int, start_z: int) -> BlockType.Type:
	var type_histogram: Dictionary = {}
	var solid_count := 0
	
	# Scan the 2x2x2 sub-grid
	for x: int in range(VOXEL_STEP):
		for y: int in range(VOXEL_STEP):
			for z: int in range(VOXEL_STEP):
				var block := chunk.get_block(start_x + x, start_y + y, start_z + z)
				if block != BlockType.Type.AIR and BlockType.is_solid(block):
					solid_count += 1
					type_histogram[block] = type_histogram.get(block, 0) + 1
					
	# If less than half of the sub-grid blocks are solid, represent it as Air (empty space)
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


## Projects the 2x2x2 scaled transform matrices for the decimated blocks.
static func _compile_decimated_transforms(render_data: Dictionary, type: BlockType.Type, rx: int, ry: int, rz: int, chunk_pos: Vector3i, world_state: WorldState) -> void:
	# Check if the face is exposed/visible on the outer boundaries of the 8x8x8 grid
	var is_visible := _check_decimated_voxel_exposure(rx, ry, rz, chunk_pos, world_state)
	if not is_visible:
		return
		
	# Draw position is offset to center the 2x2x2 scaled block in global space
	var local_offset := Vector3(float(rx * 2) + 1.0, float(ry * 2) + 1.0, float(rz * 2) + 1.0)
	var basis_scale := Basis().scaled(Vector3(2.0, 2.0, 2.0)) # 2x2x2 block dimensions
	var t := Transform3D(basis_scale, local_offset)
	
	if not render_data.has(type):
		render_data[type] = []
	render_data[type].append(t)


## Evaluates adjacency to determine if a decimated face is exposed and should be drawn.
static func _check_decimated_voxel_exposure(rx: int, ry: int, rz: int, chunk_pos: Vector3i, world_state: WorldState) -> bool:
	# Simplification: Outer edges of the 8x8x8 decimated grid are always drawn
	if rx == 0 or rx == DECIMATED_SIZE - 1 or ry == 0 or ry == DECIMATED_SIZE - 1 or rz == 0 or rz == DECIMATED_SIZE - 1:
		return true
		
	# For inner blocks, verify if any adjacent 2x2x2 block is Air
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
	return false


## Packs the calculated transform lists into high-performance float buffers.
static func _pack_decimated_float_arrays(render_data: Dictionary) -> Dictionary:
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
