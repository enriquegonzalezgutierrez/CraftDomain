# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Rendering Service responsible for evaluating raw
#              domain chunks and compiling their physical and visual transformation
#              data for rendering.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles world carving rules.
#              CPU MICRO-OPTIMIZATIONS (EXTREME PERFORMANCE):
#              - Bitwise Masking: Replaced expensive modulo (`%`) division operators 
#                with native Bitwise AND (`& 15`) for out-of-bounds neighbor wrapping. 
#                This eliminates branching and division, making C++ loop execution blisteringly fast.
#              - Packed Vectors: Upgraded the `FACE_VERTICES` dictionary to use native 
#                `PackedVector3Array` instead of generic Arrays. This eliminates 
#                dynamic `as Vector3` variant casting inside the hottest loop of the game.
#              - Distance Physics Culling: Added `build_collision` flag to completely bypass 
#                gathering triangle faces for distant chunks, saving massive CPU time.
#              PHYSICS SEAM WINDING RESTORATION (DEFINITIVE):
#              - Restored correct Counter-Clockwise (CCW) winding order (`v2, v1, v0` 
#                and `v3, v2, v0`). All normals now point outward perfectly, 
#                resolving player movement locks and ensuring ground-plane collision safety.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# ==============================================================================
class_name ChunkVisualBuilder
extends RefCounted

const CHUNK_MASK: int = 15 # Chunk.SIZE (16) - 1. Used for extreme-speed bitwise wrapping.

## 3D directional vectors for checking neighboring voxel faces.
## Evaluated once on class load.
static var DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # UP
	Vector3i(0, -1, 0),  # DOWN
	Vector3i(1, 0, 0),   # RIGHT
	Vector3i(-1, 0, 0),  # LEFT
	Vector3i(0, 0, 1),   # FRONT
	Vector3i(0, 0, -1)   # BACK
]

## Local vertex tables defining the 4 vertices per face (from origin 0,0,0 to 1,1,1).
## Optimized as PackedVector3Array to bypass Variant casting overhead in GDScript.
static var FACE_VERTICES: Dictionary = {
	Vector3i(0, 1, 0): PackedVector3Array([Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]), # TOP
	Vector3i(0, -1, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]), # BOTTOM
	Vector3i(1, 0, 0): PackedVector3Array([Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)]), # RIGHT
	Vector3i(-1, 0, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]), # LEFT
	Vector3i(0, 0, 1): PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]), # FRONT
	Vector3i(0, 0, -1): PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)])  # BACK
}


## Extracts block data from a chunk, applies occlusion culling, and packages 
## it into optimized PackedFloat32Arrays ready for MultiMesh rendering.
static func extract_render_data(chunk: Chunk, world_state: WorldState, build_collision: bool = true) -> Dictionary:
	var render_data: Dictionary = {}
	var collision_vertices := PackedVector3Array()
	
	# Pre-cache neighbor chunks to avoid costly hash-map lookups per boundary voxel
	var neighbors: Dictionary = {
		Vector3i(1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(1, 0, 0)),
		Vector3i(-1, 0, 0): world_state.get_chunk(chunk.position + Vector3i(-1, 0, 0)),
		Vector3i(0, 1, 0): world_state.get_chunk(chunk.position + Vector3i(0, 1, 0)),
		Vector3i(0, -1, 0): world_state.get_chunk(chunk.position + Vector3i(0, -1, 0)),
		Vector3i(0, 0, 1): world_state.get_chunk(chunk.position + Vector3i(0, 0, 1)),
		Vector3i(0, 0, -1): world_state.get_chunk(chunk.position + Vector3i(0, 0, -1))
	}
	
	# CPU CACHE OPTIMIZATION: Linear array access over chunk blocks
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				
				# Skip air and dynamically meshed liquids
				if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
					continue
					
				var local_pos := Vector3(float(x), float(y), float(z))
				var is_exposed: bool = false
				
				for dir: Vector3i in DIRECTIONS:
					var nx: int = x + dir.x
					var ny: int = y + dir.y
					var nz: int = z + dir.z
					
					var neighbor_type: BlockType.Type
					
					# Local chunk bounds check (ultra-fast inner grid)
					if nx >= 0 and nx < Chunk.SIZE and ny >= 0 and ny < Chunk.SIZE and nz >= 0 and nz < Chunk.SIZE:
						neighbor_type = chunk.get_block(nx, ny, nz)
					else:
						# Boundary lookup using pre-cached neighbors
						var n_chunk: Chunk = neighbors[dir]
						if n_chunk != null:
							# BITWISE MASKING OPTIMIZATION: 
							# Using `& 15` instantly maps -1 to 15, and 16 to 0 without branching or modulo division!
							var lx: int = nx & CHUNK_MASK
							var ly: int = ny & CHUNK_MASK
							var lz: int = nz & CHUNK_MASK
							neighbor_type = n_chunk.get_block(lx, ly, lz)
						else:
							# If neighbor chunk doesn't exist yet, assume exposed to prevent holes
							neighbor_type = BlockType.Type.AIR 
							
					# If the neighbor is transparent, this block is visible
					if BlockType.is_transparent(neighbor_type):
						is_exposed = true
						
						# SOW COLLISION FACES: Collect vertices of this exposed face if block is solid
						# MASSIVE OPTIMIZATION: Only build collision vertices if requested (Close chunks)
						if build_collision and BlockType.is_solid(block_type):
							var face_verts: PackedVector3Array = FACE_VERTICES[dir]
							var v0 := local_pos + face_verts[0]
							var v1 := local_pos + face_verts[1]
							var v2 := local_pos + face_verts[2]
							var v3 := local_pos + face_verts[3]
							
							# Triangle 1 (CCW - Counter-Clockwise Winding Order)
							collision_vertices.append(v2)
							collision_vertices.append(v1)
							collision_vertices.append(v0)
							
							# Triangle 2 (CCW - Counter-Clockwise Winding Order)
							collision_vertices.append(v3)
							collision_vertices.append(v2)
							collision_vertices.append(v0)

				# Skip completely buried blocks! Saves GPU, CPU, and RAM instantly.
				if not is_exposed:
					continue 
				
				var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
				var t := Transform3D(Basis(), transform_pos)
				
				if not render_data.has(block_type):
					render_data[block_type] = []
				render_data[block_type].append(t)
					
	# ======================================================================
	# BACKGROUND THREAD MEMORY PACKING
	# ======================================================================
	var final_multimesh_data: Dictionary = {}
	for b_type: BlockType.Type in render_data.keys():
		var transforms: Array = render_data[b_type] as Array
		var count: int = transforms.size()
		
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
					
	return {
		"multimesh": final_multimesh_data,
		"collision_vertices": collision_vertices
	}
