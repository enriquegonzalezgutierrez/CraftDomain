# ==============================================================================
# Project: CraftDomain
# Description: Description: Infrastructure Rendering Service responsible for evaluating raw
#              domain chunks and compiling their physical and visual transformation
#              data for rendering.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles world carving rules.
#              WARNING FIX:
#              - Added explicit static typing to all loop iterators (including `b_type`, 
#                `x`, `y`, `z`, `dir`, and `i`) to prevent all potential 
#                `UNTYPED_DECLARATION` warnings.
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

## Local vertex tables defining the 4 vertices per face (from origin 0,0,0 to 1,1,1).
const FACE_VERTICES: Dictionary = {
	Vector3i(0, 1, 0): [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)], # TOP
	Vector3i(0, -1, 0): [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], # BOTTOM
	Vector3i(1, 0, 0): [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)], # RIGHT
	Vector3i(-1, 0, 0): [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)], # LEFT
	Vector3i(0, 0, 1): [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)], # FRONT
	Vector3i(0, 0, -1): [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)]  # BACK
}

## Extracts block data from a chunk, applies occlusion culling, and packages 
## it into optimized PackedFloat32Arrays ready for MultiMesh rendering.
static func extract_render_data(chunk: Chunk, world_state: WorldState) -> Dictionary:
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
	
	# FIX: Added explicit static typing to spatial iterators
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				
				# Skip air and dynamically meshed liquids
				if block_type == BlockType.Type.AIR or block_type == BlockType.Type.WATER or block_type == BlockType.Type.LAVA:
					continue
					
				var local_pos := Vector3(x, y, z)
				var is_exposed: bool = false
				
				# FIX: Explicit static typing on directional iterators
				for dir: Vector3i in DIRECTIONS:
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
						
						# SOW COLLISION FACES: Collect vertices of this exposed face if block is solid
						if BlockType.is_solid(block_type):
							var face_verts: Array = FACE_VERTICES[dir]
							var v0 := local_pos + (face_verts[0] as Vector3)
							var v1 := local_pos + (face_verts[1] as Vector3)
							var v2 := local_pos + (face_verts[2] as Vector3)
							var v3 := local_pos + (face_verts[3] as Vector3)
							
							# Triangle 1
							collision_vertices.append(v2)
							collision_vertices.append(v1)
							collision_vertices.append(v0)
							
							# Triangle 2
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
	# FIX: Explicit type constraint on BlockType key iterator
	for b_type: BlockType.Type in render_data.keys():
		var transforms: Array = render_data[b_type] as Array
		var count: int = transforms.size()
		
		var bulk_array := PackedFloat32Array()
		bulk_array.resize(count * 12)
		
		# FIX: Explicit type constraint on index range iterator
		for i: int in range(count):
			var t: Transform3D = transforms[i] as Transform3D
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
		"collision_vertices": collision_vertices
	}
