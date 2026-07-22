# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkMesher.gd
# Description: High-performance mesh generator for non-standard voxels (Slabs, Liquids).
#              Calculates visual geometries, bakes normals, and shields liquids from AO.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkMesher
extends RefCounted

const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]

const SEAM_OVERLAP: float = 1.000


## Scans the chunk and generates all specialized meshes with selective Vertex AO.
static func generate_special_meshes(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var special_meshes: Dictionary = {}
	var processed_types: Dictionary = {}
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var b_id := chunk.get_block(x, y, z)
				if b_id == 0 or processed_types.has(b_id):
					continue
				
				var def := BlockLibrary.get_definition(b_id)
				if def.geometry is FullCubeGeometry and not def.rendering_type.begins_with("liquid"):
					continue
				processed_types[b_id] = def
				
	for b_id: int in processed_types.keys():
		var def: BlockDefinition = processed_types[b_id]
		var mesh: ArrayMesh = null
		if def.rendering_type.begins_with("liquid"):
			mesh = _generate_liquid_mesh(chunk, world_state, b_id, def)
		else:
			mesh = _generate_custom_geometry_mesh(chunk, world_state, b_id, def)
			
		if mesh != null:
			special_meshes[b_id] = mesh
		
	return special_meshes


static func _generate_liquid_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id:
					continue
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					if _evaluate_liquid_face_culling(chunk, world_state, local_pos, dir, target_id):
						_add_face_to_tool(st, local_pos, dir, def, world_state, chunk)
						faces_drawn += 1
						
	if faces_drawn == 0:
		return null
	st.generate_normals()
	return st.commit()


static func _generate_custom_geometry_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id:
					continue
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					if _evaluate_custom_face_culling(chunk, world_state, local_pos, dir):
						_add_face_to_tool(st, local_pos, dir, def, world_state, chunk)
						faces_drawn += 1
						
	if faces_drawn == 0:
		return null
	st.generate_normals()
	return st.commit()


static func _evaluate_liquid_face_culling(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, dir: Vector3i, target_id: int) -> bool:
	var n_pos := local_pos + dir
	if chunk.is_within_bounds(n_pos.x, n_pos.y, n_pos.z):
		var local_neighbor := chunk.get_block(n_pos.x, n_pos.y, n_pos.z)
		return local_neighbor != target_id and (local_neighbor == 0 or BlockLibrary.is_transparent(local_neighbor))
		
	var global_pos := (chunk.position * Chunk.SIZE) + n_pos
	var neighbor_chunk := world_state.get_chunk(world_state.global_to_chunk_pos(global_pos))
	
	if neighbor_chunk == null and dir.y == 0:
		return false
		
	var neighbor_id := world_state.get_block(global_pos)
	return neighbor_id != target_id and (neighbor_id == 0 or BlockLibrary.is_transparent(neighbor_id))


static func _evaluate_custom_face_culling(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, dir: Vector3i) -> bool:
	var neighbor_id := _get_neighbor_id(chunk, world_state, local_pos, dir)
	var neighbor_def := BlockLibrary.get_definition(neighbor_id)
	return neighbor_id == 0 or not neighbor_def.geometry.is_face_opaque(-dir)


static func _add_face_to_tool(st: SurfaceTool, local_pos: Vector3i, direction: Vector3i, def: BlockDefinition, world_state: WorldState, chunk: Chunk) -> void:
	var verts := def.geometry.get_face_collision_vertices(direction)
	if verts.size() != 4:
		return
	
	var uv_rect := def.geometry.get_face_uv_rect(direction)
	var face_color := _get_face_orientation_color(direction, def)
	
	var is_liquid := def.rendering_type.begins_with("liquid")
	var ao_color := Color.WHITE if is_liquid else _calculate_face_ao_color(chunk, world_state, local_pos, direction)
	var final_color := face_color * ao_color
	
	var offset := Vector3(local_pos)
	var uvs: Array[Vector2] = [
		Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y),
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y),
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y),
		Vector2(uv_rect.position.x, uv_rect.position.y)
	]
	
	_append_triangles_to_surface(st, verts, uvs, final_color, offset)


static func _calculate_face_ao_color(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, direction: Vector3i) -> Color:
	if world_state == null or chunk == null:
		return Color.WHITE
		
	var global_pos := (chunk.position * Chunk.SIZE) + local_pos + direction
	var side_a_pos := global_pos + Vector3i(direction.z, direction.x, direction.y)
	var side_b_pos := global_pos + Vector3i(-direction.z, -direction.x, -direction.y)
	var corner_pos := global_pos + Vector3i(direction.z, direction.x, direction.y) + Vector3i(-direction.z, -direction.x, -direction.y)
	
	return VoxelAmbientOcclusionSolver.evaluate_corner_ao(world_state, side_a_pos, side_b_pos, corner_pos)


static func _append_triangles_to_surface(st: SurfaceTool, verts: PackedVector3Array, uvs: Array[Vector2], color: Color, offset: Vector3) -> void:
	var v_indices: Array[int] = [2, 1, 0, 3, 2, 0]
	for i: int in v_indices:
		var v_final := offset + verts[i]
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(v_final)


static func _get_face_orientation_color(direction: Vector3i, def: BlockDefinition) -> Color:
	if direction.y == 1:
		return def.color_top
	elif direction.y == -1:
		return def.color_bottom
	return def.color_side


static func _get_neighbor_id(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, direction: Vector3i) -> int:
	var n_pos := local_pos + direction
	if chunk.is_within_bounds(n_pos.x, n_pos.y, n_pos.z):
		return chunk.get_block(n_pos.x, n_pos.y, n_pos.z)
	return world_state.get_block((chunk.position * Chunk.SIZE) + n_pos)
