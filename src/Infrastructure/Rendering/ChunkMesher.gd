# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering service that generates optimized 3D meshes
#              for chunks using face culling with explicit static typing and
#              outward-facing triangle winding.
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

## Generates a renderable ArrayMesh for a given chunk.
func generate_mesh(chunk: Chunk, world_state: WorldState) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var chunk_offset: Vector3i = chunk.position * Chunk.SIZE
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				
				if not BlockType.is_solid(block_type):
					continue
				
				var block_def: BlockDefinition = BlockLibrary.get_definition(block_type)
				var local_pos := Vector3i(x, y, z)
				var global_pos: Vector3i = chunk_offset + local_pos
				
				# Evaluate all 6 surrounding faces
				for dir in DIRECTIONS:
					var neighbor_global_pos: Vector3i = global_pos + dir
					var neighbor_type: BlockType.Type = world_state.get_block(neighbor_global_pos)
					
					# Draw face if the neighbor is transparent/air
					if BlockType.is_transparent(neighbor_type):
						_add_face(st, local_pos, dir, block_def)
						
	st.generate_normals()
	return st.commit()

func _add_face(st: SurfaceTool, local_pos: Vector3i, direction: Vector3i, block_def: BlockDefinition) -> void:
	var face_color: Color = _get_face_color(direction, block_def)
	var vertices: Array = FACE_VERTICES[direction]
	
	# Statically cast elements of the vertex array to ensure type safety
	var v0: Vector3 = Vector3(local_pos) + (vertices[0] as Vector3)
	var v1: Vector3 = Vector3(local_pos) + (vertices[1] as Vector3)
	var v2: Vector3 = Vector3(local_pos) + (vertices[2] as Vector3)
	var v3: Vector3 = Vector3(local_pos) + (vertices[3] as Vector3)
	
	# Triangle 1 (Reversed winding sequence to make normal point outwards)
	st.set_color(face_color)
	st.add_vertex(v2)
	st.set_color(face_color)
	st.add_vertex(v1)
	st.set_color(face_color)
	st.add_vertex(v0)
	
	# Triangle 2 (Reversed winding sequence to make normal point outwards)
	st.set_color(face_color)
	st.add_vertex(v3)
	st.set_color(face_color)
	st.add_vertex(v2)
	st.set_color(face_color)
	st.add_vertex(v0)

func _get_face_color(direction: Vector3i, block_def: BlockDefinition) -> Color:
	if direction.y == 1:
		return block_def.color_top
	elif direction.y == -1:
		return block_def.color_bottom
	return block_def.color_side
