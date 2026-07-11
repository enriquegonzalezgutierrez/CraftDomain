# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Rendering / Meshing)
# Class: ChunkMesher
# Description: High-performance mesh generator for non-standard voxels.
#              Orchestrates the construction of liquid surfaces and custom 
#              solid geometries (like Slabs) using face-culling algorithms.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively the translation 
#   of voxel data into GPU-ready ArrayMeshes.
# - Open-Closed Principle (OCP): COMPLETELY DECOUPLED. This class no longer 
#   contains any hardcoded Block IDs. It polymorphically consumes the 'geometry' 
#   and 'rendering_type' properties defined in the Domain Block files.
# TRANSLUCENT SEAMS OPTIMIZATION:
# - Disabled the `SEAM_OVERLAP` scaling factor for transparent or liquid blocks.
#   Keeping their vertices strictly at a 1.0 scale allows transparent faces 
#   to stitch perfectly at chunk borders without overlapping, completely 
#   eliminating dark Alpha-Overlapping seam artifacts.
# ==============================================================================
class_name ChunkMesher
extends RefCounted

## Direction vectors for 6-face cubic adjacency checks
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # TOP
	Vector3i(0, -1, 0),  # BOTTOM
	Vector3i(1, 0, 0),   # RIGHT
	Vector3i(-1, 0, 0),  # LEFT
	Vector3i(0, 0, 1),   # FRONT
	Vector3i(0, 0, -1)   # BACK
]

## Factor used to slightly overlap faces to prevent sub-pixel light leaks in solid blocks
const SEAM_OVERLAP: float = 1.002


## DISPATCHER: Scans the chunk and generates all specialized meshes (Liquids/Custom)
## Returns a Dictionary: int (block_id) -> ArrayMesh
static func generate_special_meshes(chunk: Chunk, world_state: WorldState) -> Dictionary:
	var special_meshes: Dictionary = {}
	var processed_types: Dictionary = {}
	
	# 1. Identify which special blocks exist in this chunk
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var b_id := chunk.get_block(x, y, z)
				if b_id == 0 or processed_types.has(b_id):
					continue
					
				var def := BlockLibrary.get_definition(b_id)
				# Standard cubes are handled by MultiMesh in ChunkVisualBuilder, skip them here
				if def.geometry is FullCubeGeometry and not def.rendering_type.begins_with("liquid"):
					continue
					
				processed_types[b_id] = def
				
	# 2. Compile meshes for each unique special type found
	for b_id: int in processed_types.keys():
		var def: BlockDefinition = processed_types[b_id]
		var mesh: ArrayMesh
		
		if def.rendering_type.begins_with("liquid"):
			mesh = _generate_liquid_mesh(chunk, world_state, b_id, def)
		else:
			mesh = _generate_custom_geometry_mesh(chunk, world_state, b_id, def)
			
		if mesh != null:
			special_meshes[b_id] = mesh
			
	return special_meshes


## GENERIC LIQUID GENERATOR: Handles Water, Lava, or any future fluid polymorphically.
static func _generate_liquid_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id:
					continue
					
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					# ==========================================================
					# STRICT LIQUID CULLING RULE
					# Only draw the liquid face if the neighbor is AIR, or is another 
					# TRANSPARENT material (like Glass/Leaves) that is not the same liquid.
					# ==========================================================
					var neighbor_id := _get_neighbor_id(chunk, world_state, local_pos, dir)
					var should_draw := false
					
					if neighbor_id == 0: # AIR
						should_draw = true
					elif neighbor_id != target_id:
						var neighbor_def := BlockLibrary.get_definition(neighbor_id)
						if neighbor_def != null and neighbor_def.is_transparent:
							should_draw = true
							
					if should_draw:
						_add_face_to_tool(st, local_pos, dir, def)
						faces_drawn += 1
						
	if faces_drawn == 0:
		return null
		
	# Generar normales para permitir luces y desplazamientos en los shaders del agua
	st.generate_normals()
	return st.commit()


## GENERIC CUSTOM GEOMETRY GENERATOR: Handles Slabs, Stairs, or Fences polymorphically.
static func _generate_custom_geometry_mesh(chunk: Chunk, world_state: WorldState, target_id: int, def: BlockDefinition) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces_drawn := 0
	
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				if chunk.get_block(x, y, z) != target_id:
					continue
					
				var local_pos := Vector3i(x, y, z)
				
				for dir: Vector3i in DIRECTIONS:
					# Custom Geometry culling: Draw face if neighbor is air or doesn't cover this face opaquely
					var neighbor_id := _get_neighbor_id(chunk, world_state, local_pos, dir)
					var neighbor_def := BlockLibrary.get_definition(neighbor_id)
					
					var is_visible := neighbor_id == 0 or not neighbor_def.geometry.is_face_opaque(-dir)
					
					if is_visible:
						_add_face_to_tool(st, local_pos, dir, def)
						faces_drawn += 1
						
	if faces_drawn == 0:
		return null
		
	# Generar normales para habilitar PBR en geometrías personalizadas
	st.generate_normals()
	return st.commit()


## Low-level Vertex Assembler: Feeds from the IVoxelGeometry Domain Contract.
static func _add_face_to_tool(st: SurfaceTool, local_pos: Vector3i, direction: Vector3i, def: BlockDefinition) -> void:
	# Fetch procedural data from the Strategy
	var verts := def.geometry.get_face_collision_vertices(direction)
	var uv_rect := def.geometry.get_face_uv_rect(direction)
	
	if verts.size() != 4: return
	
	# Determine color based on face orientation (Top/Side/Bottom)
	var face_color := def.color_side
	if direction.y == 1: face_color = def.color_top
	elif direction.y == -1: face_color = def.color_bottom
	
	var offset := Vector3(local_pos)
	var center := offset + Vector3(0.5, 0.5, 0.5)
	
	# Map UVs to the corners of the geometry face
	var uvs := [
		Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y), # BL
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y), # BR
		Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y), # TR
		Vector2(uv_rect.position.x, uv_rect.position.y) # TL
	]
	
	# ==========================================================================
	# TACTICAL SEAM OVERLAP PRESERVATION (GRAPHICS OPTIMIZATION)
	# Solid opaque blocks require a 1.002 scaling factor to prevent sub-pixel 
	# light leaks and Z-fighting at chunk borders. However, for transparent/translucent
	# blocks (like Water, Glass, or Clouds), scaling vertices causes overlapping alpha-blended
	# faces on joints, creating dark/bright seam artifacts.
	# We strictly use a factor of 1.0 (no overlap) for transparent materials.
	# ==========================================================================
	var overlap_factor: float = SEAM_OVERLAP
	if def.is_transparent or def.rendering_type.begins_with("liquid"):
		overlap_factor = 1.0
	# ==========================================================================
	
	# Assemble 2 Triangles per face with CW/CCW winding safety and seam overlap
	var v_indices: Array[int] = [2, 1, 0, 3, 2, 0] # Standard triangle split
	
	for i: int in v_indices:
		var v_raw: Vector3 = verts[i]
		# Apply calculated overlap scaling
		var v_final := (offset + v_raw - center) * overlap_factor + center
		
		st.set_color(face_color)
		st.set_uv(uvs[i])
		st.add_vertex(v_final)


## Safe adjacency scanner wrapping chunk boundaries
static func _get_neighbor_id(chunk: Chunk, world_state: WorldState, local_pos: Vector3i, direction: Vector3i) -> int:
	var n_pos := local_pos + direction
	if chunk.is_within_bounds(n_pos.x, n_pos.y, n_pos.z):
		return chunk.get_block(n_pos.x, n_pos.y, n_pos.z)
	
	# Boundary fallback: query global world state
	var global_pos := (chunk.position * Chunk.SIZE) + n_pos
	return world_state.get_block(global_pos)
