# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/GrandCastleMegaStructure.gd
# Description: Handcrafted two-story colossal fortress.
#              SOLID COMPLIANCE: Monolithic 'build_chunk' loop decomposed into 
#              isolated, SRP-compliant sculpt methods (< 20 lines each).
#              Corrected: Explicit static typing to resolve compiler inference errors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GrandCastleMegaStructure
extends IMegaStructure

# --- PERIMETER & BASELINE GEOMETRY CONSTANTS ---
const BASE_ALTITUDE_Y: int = 12           
const CASTLE_WALL_RADIUS: int = 24        
const KEEP_WIDTH_HALF: int = 12           
const KEEP_LENGTH_HALF: int = 12          
const CORNER_TOWER_RADIUS: int = 4        

# --- OUTER RAMPARTS & VERTICAL LEVELS ---
const RAMPART_MAX_LEVEL: int = 7          
const TOWER_MAX_LEVEL: int = 14           
const TOWER_FLOOR_A: int = 6              
const TOWER_FLOOR_B: int = 11             

# --- INTERNAL KEEP ROOM CONSTANTS ---
const KEEP_MAX_LEVEL: int = 17            
const LEVEL_MEZZANINE_FLOOR: int = 6      
const LEVEL_ROOFTOP_SLAB: int = 13        
const THRONE_HALL_LIMIT_X: int = 6        
const PARTITION_WALL_LIMIT_X: int = 7     


func _init() -> void:
	global_center = Vector2i(200, 200) 
	bounds_size = Vector2i(60, 60)


func get_name() -> String:
	return "STRUCTURE_GRAND_CASTLE"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var b_min_x: int = global_center.x - floori(float(bounds_size.x) / 2.0)
	var b_max_x: int = global_center.x + floori(float(bounds_size.x) / 2.0)
	var b_min_z: int = global_center.y - floori(float(bounds_size.y) / 2.0)
	var b_max_z: int = global_center.y + floori(float(bounds_size.y) / 2.0)
	
	for gx: int in range(b_min_x, b_max_x + 1):
		for gz: int in range(b_min_z, b_max_z + 1):
			_sculpt_vertical_column(chunk, offset, gx, gz)


func _sculpt_vertical_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var dist_x: int = abs(gx - global_center.x)
	var dist_z: int = abs(gz - global_center.y)
	
	_sculpt_terrain_baseline(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_outer_walls(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_corner_towers(chunk, offset, gx, gz)
	_sculpt_central_keep(chunk, offset, gx, gz)
	_sculpt_rooftop_dome(chunk, offset, gx, gz)


func _sculpt_terrain_baseline(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int) -> void:
	if dist_x <= CASTLE_WALL_RADIUS and dist_z <= CASTLE_WALL_RADIUS:
		for gy: int in range(BASE_ALTITUDE_Y + 1, 32):
			_clear_air_block(chunk, offset, gx, gz, gy)
			
	for gy: int in range(0, BASE_ALTITUDE_Y + 1):
		var ly: int = gy - offset.y
		if not chunk.is_within_bounds(gx - offset.x, ly, gz - offset.z): continue
		
		if gy < BASE_ALTITUDE_Y:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE)
		elif gy == BASE_ALTITUDE_Y:
			var is_stone: bool = (abs(gx - global_center.x) <= 2 and gz >= global_center.y + CASTLE_WALL_RADIUS) or (dist_x < KEEP_WIDTH_HALF and dist_z < KEEP_LENGTH_HALF)
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE if is_stone else BlockType.Type.GRASS)


func _clear_air_block(chunk: Chunk, offset: Vector3i, gx: int, gz: int, gy: int) -> void:
	var lx := gx - offset.x
	var ly := gy - offset.y
	var lz := gz - offset.z
	if chunk.is_within_bounds(lx, ly, lz):
		chunk.set_block(lx, ly, lz, BlockType.Type.AIR)


func _sculpt_outer_walls(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int) -> void:
	var is_wall_border: bool = (dist_x == CASTLE_WALL_RADIUS and dist_z <= CASTLE_WALL_RADIUS) or (dist_z == CASTLE_WALL_RADIUS and dist_x <= CASTLE_WALL_RADIUS)
	if not is_wall_border: return
		
	var is_gate: bool = (gz == global_center.y + CASTLE_WALL_RADIUS) and (dist_x <= 3)
	for wy: int in range(1, RAMPART_MAX_LEVEL + 2):
		if is_gate and wy <= 5: continue
			
		if wy == RAMPART_MAX_LEVEL + 1 and (gx + gz) % 2 == 0: continue
		set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y + wy, gz, BlockType.Type.STONE)


func _sculpt_corner_towers(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var tx: int = 0
	var tz: int = 0
	var is_in_tower := false
	var c_rad := CASTLE_WALL_RADIUS
	
	if abs(gx - (global_center.x - c_rad)) <= CORNER_TOWER_RADIUS and abs(gz - (global_center.y - c_rad)) <= CORNER_TOWER_RADIUS:
		is_in_tower = true; tx = global_center.x - c_rad; tz = global_center.y - c_rad
	elif abs(gx - (global_center.x + c_rad)) <= CORNER_TOWER_RADIUS and abs(gz - (global_center.y - c_rad)) <= CORNER_TOWER_RADIUS:
		is_in_tower = true; tx = global_center.x + c_rad; tz = global_center.y - c_rad
	elif abs(gx - (global_center.x - c_rad)) <= CORNER_TOWER_RADIUS and abs(gz - (global_center.y + c_rad)) <= CORNER_TOWER_RADIUS:
		is_in_tower = true; tx = global_center.x - c_rad; tz = global_center.y + c_rad
	elif abs(gx - (global_center.x + c_rad)) <= CORNER_TOWER_RADIUS and abs(gz - (global_center.y + c_rad)) <= CORNER_TOWER_RADIUS:
		is_in_tower = true; tx = global_center.x + c_rad; tz = global_center.y + c_rad
		
	if is_in_tower:
		_build_tower_cylinder(chunk, offset, gx, gz, tx, tz)


func _build_tower_cylinder(chunk: Chunk, offset: Vector3i, gx: int, gz: int, tx: int, tz: int) -> void:
	var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
	if t_dist > float(CORNER_TOWER_RADIUS): return
		
	for wy: int in range(1, TOWER_MAX_LEVEL + 2):
		var cy: int = BASE_ALTITUDE_Y + wy
		var is_wall: bool = t_dist > float(CORNER_TOWER_RADIUS) - 1.5
		if is_wall:
			if wy == TOWER_MAX_LEVEL + 1 and (gx + gz) % 2 == 0: continue
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
		else:
			var b_type := BlockType.Type.OAK_PLANKS if (wy == TOWER_FLOOR_A or wy == TOWER_FLOOR_B) else BlockType.Type.AIR
			set_global_block(chunk, offset, gx, cy, gz, b_type)


func _sculpt_central_keep(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var keep_center_z: int = global_center.y - 6 
	var k_dx: int = abs(gx - global_center.x)
	var k_dz: int = abs(gz - keep_center_z)
	
	if k_dx > KEEP_WIDTH_HALF or k_dz > KEEP_LENGTH_HALF: return
		
	var is_wall: bool = (k_dx == KEEP_WIDTH_HALF or k_dz == KEEP_LENGTH_HALF)
	var is_gate: bool = (gz == keep_center_z + KEEP_LENGTH_HALF) and (k_dx <= 3)
	
	for wy: int in range(1, KEEP_MAX_LEVEL + 1):
		var cy: int = BASE_ALTITUDE_Y + wy
		if is_wall:
			_build_keep_exterior_wall(chunk, offset, gx, gz, cy, wy, k_dx, k_dz, is_gate)
		else:
			_build_keep_interior(chunk, offset, gx, gz, cy, wy, k_dx, keep_center_z)


func _build_keep_exterior_wall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_dz: int, is_gate: bool) -> void:
	if is_gate and wy <= 5: return
	var is_win: bool = (wy == 3 or wy == 11) and ((k_dx == KEEP_WIDTH_HALF and gz % 4 == 0) or (k_dz == KEEP_LENGTH_HALF and gx % 4 == 0))
	var b_type := BlockType.Type.GLASS if (is_win and not is_gate) else BlockType.Type.STONE
	set_global_block(chunk, offset, gx, cy, gz, b_type)


func _build_keep_interior(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_cz: int) -> void:
	if k_dx <= THRONE_HALL_LIMIT_X:
		_build_throne_hall(chunk, offset, gx, gz, cy, wy, k_dx, k_cz)
	else:
		_build_side_wings(chunk, offset, gx, gz, cy, wy, k_dx, k_cz)


func _build_throne_hall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_cz: int) -> void:
	if wy <= LEVEL_MEZZANINE_FLOOR - 1:
		_build_throne_ground_floor(chunk, offset, gx, gz, cy, wy, k_dx, k_cz)
	elif wy == LEVEL_MEZZANINE_FLOOR:
		var is_open: bool = (gx >= 189 and gx <= 191 and gz >= 185 and gz <= 187) or (gx >= 209 and gx <= 211 and gz >= 185 and gz <= 187) or (gx >= 192 and gx <= 208 and gz >= 188)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_open else BlockType.Type.OAK_PLANKS)
	elif wy <= LEVEL_ROOFTOP_SLAB - 1:
		_build_throne_upper_floor(chunk, offset, gx, gz, cy, wy, k_dx, k_cz)
	elif wy == LEVEL_ROOFTOP_SLAB:
		var is_hatch: bool = (gx >= 189 and gx <= 190) and (gz == k_cz - KEEP_LENGTH_HALF + 3)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_hatch else BlockType.Type.STONE)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_throne_ground_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_cz: int) -> void:
	if k_dx <= 1 and gz >= k_cz - KEEP_LENGTH_HALF + 3:
		if wy == 1: set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y, gz, BlockType.Type.RED_SAND)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
	elif gx == global_center.x and gz == k_cz - KEEP_LENGTH_HALF + 2:
		var blocks: Array[BlockType.Type] = [BlockType.Type.AIR, BlockType.Type.STONE, BlockType.Type.OAK_PLANKS, BlockType.Type.NEON_MAGENTA, BlockType.Type.GLOWSTONE]
		var type: BlockType.Type = blocks[wy] if wy <= 4 else BlockType.Type.AIR
		set_global_block(chunk, offset, gx, cy, gz, type)
	elif gz >= 185 and gz <= 196 and (gx >= 189 and gx <= 191 or gx >= 209 and gx <= 211):
		var step_req: int = floori(float(196 - gz) / 2.0) + 1
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if wy <= step_req else BlockType.Type.AIR)
	elif k_dx == 5 and (gz == k_cz or gz == k_cz + 4):
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (wy == 1 or wy == 5) else BlockType.Type.NEON_CYAN)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_throne_upper_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_cz: int) -> void:
	var is_rail: bool = (wy == 7) and (k_dx == 8 and gz >= 188)
	var is_stair: bool = (gz == k_cz - KEEP_LENGTH_HALF + 3) and (gx >= 189 and gx <= 194)
	if is_rail:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
	elif is_stair:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (wy - 6) <= (195 - gx) else BlockType.Type.AIR)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_side_wings(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int, k_cz: int) -> void:
	if k_dx == PARTITION_WALL_LIMIT_X:
		var is_door: bool = (gz == k_cz) and ((wy >= 1 and wy <= 3) or (wy >= 7 and wy <= 9))
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_door else BlockType.Type.STONE)
	else:
		_build_wing_rooms(chunk, offset, gx, gz, cy, wy, k_dx)


func _build_wing_rooms(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, k_dx: int) -> void:
	if wy <= LEVEL_MEZZANINE_FLOOR - 1:
		if gz == 194:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if (k_dx == 9 and wy <= 3) else BlockType.Type.STONE)
		else:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
	elif wy == LEVEL_MEZZANINE_FLOOR:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.OAK_PLANKS)
	elif wy <= LEVEL_ROOFTOP_SLAB - 1:
		_build_wing_upper_rooms(chunk, offset, gx, gz, cy, wy)
	elif wy == LEVEL_ROOFTOP_SLAB:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_wing_upper_rooms(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if gz == 194:
		var is_door: bool = (gx == 190 or gx == 210) and wy <= 9
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_door else BlockType.Type.STONE)
	else:
		if gx < global_center.x and gz < 194:
			var is_bed: bool = (gx >= 189 and gx <= 190) and (gz >= 185 and gz <= 187) and wy == 7
			var is_pil: bool = (gx >= 189 and gx <= 190) and (gz == 185) and wy == 8
			if is_bed: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
			elif is_pil: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.CLOUD)
			else: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
		elif gx > global_center.x and gz < 194:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.BRICKS if (gx == 210 and gz == 185 and wy == 7) else BlockType.Type.AIR)
		else:
			var is_tbl: bool = (gx >= 208 and gx <= 210) and (gz >= 198 and gz <= 201) and wy == 7
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD if is_tbl else BlockType.Type.AIR)


func _sculpt_rooftop_dome(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var k_cz: int = global_center.y - 6 
	var k_dx: int = abs(gx - global_center.x)
	var k_dz: int = abs(gz - k_cz)
	
	if k_dx > KEEP_WIDTH_HALF or k_dz > KEEP_LENGTH_HALF: return
		
	var is_edge: bool = (k_dx == KEEP_WIDTH_HALF or k_dz == KEEP_LENGTH_HALF)
	for wy: int in range(14, 18):
		var cy: int = BASE_ALTITUDE_Y + wy
		if is_edge:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (wy == 14 and (gx + gz) % 2 == 0) else BlockType.Type.AIR)
		else:
			var is_dome: bool = (k_dx == 3 and k_dz == 3)
			if is_dome and wy <= 16:
				set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
			elif k_dx <= 3 and k_dz <= 3 and wy == 17:
				set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.BRICKS)
			else:
				if wy >= 14: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	var ground_y := float(BASE_ALTITUDE_Y + 1)
	
	if chunk_pos.x == 12 and chunk_pos.z == 12:
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x - 3) + 0.5, ground_y, float(global_center.y + CASTLE_WALL_RADIUS) + 0.5)})
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x + 2) + 0.5, ground_y, float(global_center.y + CASTLE_WALL_RADIUS) + 0.5)})
		entities.append({"mob_id": 202, "pos": Vector3(float(global_center.x - 4) + 0.5, ground_y, float(global_center.y + 18) + 0.5)})
		entities.append({"mob_id": 202, "pos": Vector3(float(global_center.x + 3) + 0.5, ground_y, float(global_center.y + 18) + 0.5)})
		entities.append({"mob_id": 203, "pos": Vector3(float(global_center.x - 6) + 0.5, ground_y, float(global_center.y + 12) + 0.5)})
	elif chunk_pos.x == 12 and chunk_pos.z == 11:
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x - 3) + 0.5, ground_y, float(global_center.y - 15) + 0.5)})
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x + 2) + 0.5, ground_y, float(global_center.y - 15) + 0.5)})
		entities.append({"mob_id": 100, "pos": Vector3(float(global_center.x) + 0.5, ground_y + 1.0, float(global_center.y - 14) + 0.5)})
	elif chunk_pos.x == 13 and chunk_pos.z == 11:
		var treasury_y := float(BASE_ALTITUDE_Y + 7.5) 
		entities.append({"mob_id": 102, "pos": Vector3(208.5, treasury_y, 188.5)})
		entities.append({"mob_id": 200, "pos": Vector3(210.5, treasury_y + 0.5, 185.5)})
	elif chunk_pos.x == 11 and chunk_pos.z == 11:
		entities.append({"mob_id": 102, "pos": Vector3(191.5, ground_y, 189.5)})
		
	return entities
