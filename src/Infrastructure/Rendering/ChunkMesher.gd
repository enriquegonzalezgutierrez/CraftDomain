# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/ChunkMesher.gd
# Description: High-performance mesh generator for non-standard voxels (Slabs, Liquids).
#              Calculates visual geometries and bakes face normals. Decomposed (SRP).
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

const SEAM_OVERLAP: float = 1.002


## DISPATCHER: Scans the chunk and generates all specialized meshes
static func generate_special_meshes(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var special_meshes: Dictionary = {}
	var processed_types: Dictionary = {}
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var b_id := chunk.get_block(x, y, z)
				if b_id == 0 or processed_types.has(b_id): continue
				
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
			
		if mesh != null: special_meshes[b_id] = mesh
	return special_meshes


static func _generate_liquid_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id: continue
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					if _evaluate_liquid_face_culling(chunk, world_state, local_pos, dir, target_id):
						_add_face_to_tool(st, local_pos, dir, def)
						faces_drawn += 1
						
	if faces_drawn == 0: return null
	st.generate_normals()
	return st.commit()


static func _generate_custom_geometry_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id: continue
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					if _evaluate_custom_face_culling(chunk, world_state, local_pos, dir):
						_add_face_to_tool(st, local_pos, dir, def)
						faces_drawn += 1
						
	if faces_drawn == 0: return null
	st.generate_normals()
	return st.commit()


static func _evaluate_liquid_face_culling(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, dir: Vector3i, target_id: int) -> bool:
	var neighbor_id := _get_neighbor_id(chunk, world_state, local_pos, dir)
	if neighbor_id == 0: 
		return true
		
	if neighbor_id != target_id:
		var neighbor_def := BlockLibrary.get_definition(neighbor_id)
		if neighbor_def != null and neighbor_def.is_transparent:
			return true
	return false


static func _evaluate_custom_face_culling(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, dir: Vector3i) -> bool:
	var neighbor_id := _get_neighbor_id(chunk, world_state, local_pos, dir)
	var neighbor_def := BlockLibrary.get_definition(neighbor_id)
	return neighbor_id == 0 or not neighbor_def.geometry.is_face_opaque(-dir)


static func _add_face_to_tool(st: SurfaceTool, local_pos: Vector3i, direction: Vector3i, def: BlockDefinition) -> void:
	var verts := def.geometry.get_face_collision_vertices(direction)
	if verts.size() != 4: return
	
	var uv_rect := def.geometry.get_face_uv_rect(direction)
	var face_color := _get_face_orientation_color(direction, def)
	
	var offset := Vector3(local_pos)
	var center := offset + Vector3(0.5, 0.5, 0.5)
	
	var uvs: Array[Vector2] = [
		Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y),
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y),
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y),
		Vector2(uv_rect.position.x, uv_rect.position.y)
	]
	
	var overlap := 1.0 if (def.is_transparent or def.rendering_type.begins_with("liquid")) else SEAM_OVERLAP
	_append_triangles_to_surface(st, verts, uvs, face_color, offset, center, overlap)


static func _append_triangles_to_surface(st: SurfaceTool, verts: PackedVector3Array, uvs: Array[Vector2], color: Color, offset: Vector3, center: Vector3, overlap: float) -> void:
	var v_indices: Array[int] = [2, 1, 0, 3, 2, 0]
	for i: int in v_indices:
		var v_raw := verts[i]
		var v_final := (offset + v_raw - center) * overlap + center
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
	var global_pos := (chunk.position * Chunk.SIZE) + n_pos
	return world_state.get_block(global_pos)
