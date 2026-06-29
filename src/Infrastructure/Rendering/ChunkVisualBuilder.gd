# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Rendering Service responsible for evaluating raw
#              domain chunks and compiling their physical and visual transformation
#              data for rendering.
#              PERFORMANCE UPGRADE: 
#              - Implemented robust Occlusion Culling to eliminate hidden geometry.
#              - Pre-caching neighbor chunks for ultra-fast boundary lookups.
#              - Memory packing (PackedFloat32Array) offloaded to the background 
#                thread to prevent main-thread stuttering (GC Spikes).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# ==============================================================================
class_name ChunkVisualBuilder
extends RefCounted

## 3D directional vectors for checking neighboring voxel faces
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0), 
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), 
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]

## Extracts block data from a chunk, applies occlusion culling, and packages 
## it into optimized PackedFloat32Arrays ready for MultiMesh rendering.
static func extract_render_data(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var render_data: Dictionary = {}
	var collision_transforms: Array[Transform3D] = []
	
	# Pre-cache neighbor chunks to avoid costly hash-map lookups per boundary voxel
	var neighbors: Dictionary = {
		Vector3i(1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(1, 0, 0)),
		Vector3i(-1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(-1, 0, 0)),
		Vector3i(0, 1, 0): world_state.get_chunk(chunk.position + Vector3i(0, 1, 0)),
		Vector3i(0, -1, 0): world_state.get_chunk(chunk.position + Vector3i(0, -1, 0)),
		Vector3i(0, 0, 1): world_state.get_chunk(chunk.position + Vector3i(0, 0, 1)),
		Vector3i(0, 0, -1): world_state.get_chunk(chunk.position + Vector3i(0, 0, -1))
	}
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				
				# Skip air and dynamically meshed liquids
				if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
					continue
					
				# ==========================================================
				# MASSIVE OCCLUSION CULLING
				# ==========================================================
				var is_exposed: bool = false
				
				for dir in DIRECTIONS:
					var nx: int = x + dir.x
					var ny: int = y + dir.y
					var nz: int = z + dir.z
					
					var neighbor_type: BlockType.Type
					
					# Local chunk bounds check (ultra-fast)
					if nx >= 0 and nx < Chunk.SIZE and ny >= 0 and ny < Chunk.SIZE and nz >= 0 and nz < Chunk.SIZE:
						neighbor_type = chunk.get_block(nx, ny, nz)
					else:
						# Boundary lookup using pre-cached neighbors
						var n_chunk: Chunk = neighbors[dir]
						if n_chunk != null:
							# Wrap coordinates for local lookup in the neighbor chunk
							var lx: int = nx if nx >= 0 and nx < Chunk.SIZE else (nx + Chunk.SIZE) % Chunk.SIZE
							var ly: int = ny if ny >= 0 and ny < Chunk.SIZE else (ny + Chunk.SIZE) % Chunk.SIZE
							var lz: int = nz if nz >= 0 and nz < Chunk.SIZE else (nz + Chunk.SIZE) % Chunk.SIZE
							neighbor_type = n_chunk.get_block(lx, ly, lz)
						else:
							# If neighbor chunk doesn't exist yet, assume exposed to prevent holes
							neighbor_type = BlockType.Type.AIR 
							
					# If the neighbor is transparent, this block is visible
					if BlockType.is_transparent(neighbor_type):
						is_exposed = true
						break
				
				# Skip completely buried blocks! Saves GPU, CPU, and RAM instantly.
				if not is_exposed:
					continue 
				
				var local_pos := Vector3(x, y, z)
				var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
				var t := Transform3D(Basis(), transform_pos)
				
				if not render_data.has(block_type):
					render_data[block_type] = []
				render_data[block_type].append(t)
				
				if BlockType.is_solid(block_type):
					collision_transforms.append(t)
					
	# ======================================================================
	# BACKGROUND THREAD MEMORY PACKING
	# ======================================================================
	var final_multimesh_data: Dictionary = {}
	for b_type in render_data.keys():
		var transforms: Array = render_data[b_type]
		var count: int = transforms.size()
		
		var bulk_array := PackedFloat32Array()
		bulk_array.resize(count * 12)
		
		for i in range(count):
			var t: Transform3D = transforms[i]
			var offset := i * 12
			bulk_array[offset + 0] = t.basis.x.x
			bulk_array[offset + 1] = t.basis.y.x
			bulk_array[offset + 2] = t.basis.z.x
			bulk_array[offset + 3] = t.origin.x
			bulk_array[offset + 4] = t.basis.x.y
			bulk_array[offset + 5] = t.basis.y.y
			bulk_array[offset + 6] = t.basis.z.y
			bulk_array[offset + 7] = t.origin.y
			bulk_array[offset + 8] = t.basis.x.z
			bulk_array[offset + 9] = t.basis.y.z
			bulk_array[offset + 10] = t.basis.z.z
			bulk_array[offset + 11] = t.origin.z
			
		final_multimesh_data[b_type] = bulk_array
					
	return {
		"multimesh": final_multimesh_data,
		"collision": collision_transforms
	}
