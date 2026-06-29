# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering service that generates optimized 3D meshes
#              for chunks using face culling with explicit static typing.
#              LIQUID UPGRADE: Added generate_liquid_mesh with intelligent mutual
#              face culling to create seamless, crystal-clear water and lava bodies.
#              LOCAL CHECK FIX: Optimized neighbors lookup to check local chunk bounds
#              first, preventing asynchronous air-read leaks and clearing inner grids.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkMesher.gd
# ==============================================================================
class_name ChunkMesher
extends RefCounted

## Direction vectors mapping the 6 faces of a voxel, statically typed as Vector3i.
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # TOP
	Vector3i(0, -1, 0),  # BOTTOM
	Vector3i(1, 0, 0),   # RIGHT
	Vector3i(-1, 0, 0),  # LEFT
	Vector3i(0, 0, 1),   # FRONT
	Vector3i(0, 0, -1)   # BACK
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

## Generates a seamless, single-surface Mesh for transparent liquids (Water / Lava)
static func generate_liquid_mesh(chunk: Chunk, world_state: WorldState, target_type: BlockType.Type) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var chunk_offset: Vector3i = chunk.position * Chunk.SIZE
	var block_def := BlockLibrary.get_definition(target_type)
	var faces_drawn := 0
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block := chunk.get_block(x, y, z)
				if block != target_type:
					continue
					
				var local_pos := Vector3i(x, y, z)
				var global_pos := chunk_offset + local_pos
				
				# Evaluate the 6 faces of this liquid block
				for dir in DIRECTIONS:
					var neighbor_local: Vector3i = local_pos + dir
					var neighbor: BlockType.Type = BlockType.Type.AIR
					
					# HIERARCHY CHECK: Verify local bounds first to prevent asynchronous void readings!
					if chunk.is_within_bounds(neighbor_local.x, neighbor_local.y, neighbor_local.z):
						neighbor = chunk.get_block(neighbor_local.x, neighbor_local.y, neighbor_local.z)
					else:
						# If the neighbor is in an adjacent chunk, fallback to the global world state
						var neighbor_global: Vector3i = global_pos + dir
						neighbor = world_state.get_block(neighbor_global)
					
					# SEAMLESS CULLING RULE: 
					# Draw the face ONLY if the adjacent block is air or another transparent 
					# material that is NOT of our same type (e.g. water next to water is culled!).
					var should_draw := false
					if neighbor == BlockType.Type.AIR:
						should_draw = true
					elif BlockType.is_transparent(neighbor) and neighbor != target_type:
						should_draw = true
						
					if should_draw:
						_add_face(st, local_pos, dir, block_def)
						faces_drawn += 1
						
	if faces_drawn == 0:
		return null
		
	st.generate_normals()
	return st.commit()

static func _add_face(st: SurfaceTool, local_pos: Vector3i, direction: Vector3i, block_def: BlockDefinition) -> void:
	var face_color: Color = block_def.color_top
	if direction.y == -1:
		face_color = block_def.color_bottom
	elif direction.y != 1:
		face_color = block_def.color_side
		
	var vertices: Array = FACE_VERTICES[direction]
	
	var v0: Vector3 = Vector3(local_pos) + (vertices[0] as Vector3)
	var v1: Vector3 = Vector3(local_pos) + (vertices[1] as Vector3)
	var v2: Vector3 = Vector3(local_pos) + (vertices[2] as Vector3)
	var v3: Vector3 = Vector3(local_pos) + (vertices[3] as Vector3)
	
	# Triangle 1
	st.set_color(face_color)
	st.add_vertex(v2)
	st.set_color(face_color)
	st.add_vertex(v1)
	st.set_color(face_color)
	st.add_vertex(v0)
	
	# Triangle 2
	st.set_color(face_color)
	st.add_vertex(v3)
	st.set_color(face_color)
	st.add_vertex(v2)
	st.set_color(face_color)
	st.add_vertex(v0)
