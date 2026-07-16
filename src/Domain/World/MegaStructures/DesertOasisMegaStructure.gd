# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/DesertOasisMegaStructure.gd
# Description: Handcrafted two-story step-pyramid and oasis sanctuary.
#              Provides structured multi-floor dungeon parameters.
#              SOLID COMPLIANCE: Monolithic 'build_chunk' loop decomposed into 
#              isolated, SRP-compliant sculpt methods (< 20 lines each).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DesertOasisMegaStructure
extends IMegaStructure

# --- PERIMETER & BASELINE GEOMETRY CONSTANTS ---
const PYRAMID_BASE_RADIUS: int = 12       
const PYRAMID_HEIGHT: int = 10            
const BASE_ALTITUDE_Y: int = 15           
const OASIS_POOL_LIMIT_X: int = 16        
const OASIS_POOL_LIMIT_Z: int = 3         

# --- INTERNAL INTERIOR CHAMBER CONSTANTS ---
const LEVEL_HOLLOW_HALL: int = 4          
const LEVEL_CEILING_DIVISION: int = 5     
const LEVEL_MEZZANINE_CORRIDOR: int = 8   
const LEVEL_ROOFTOP_SLAB: int = 9         
const LEVEL_BEACON_FARO: int = 10         
const LEVEL_BEACON_CROWN: int = 11        

# --- COORDINATES SEGREGATION CONSTANTS ---
const RADIUS_INNER_SANCTUARY: int = 5     
const LIMIT_WEST_VAULT: int = -6          


func _init() -> void:
	global_center = Vector2i(-150, 250) 
	bounds_size = Vector2i(40, 40)


func get_name() -> String:
	return "STRUCTURE_DESERT_OASIS"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var min_x: int = global_center.x - floori(float(bounds_size.x) / 2.0)
	var max_x: int = global_center.x + floori(float(bounds_size.x) / 2.0)
	var min_z: int = global_center.y - floori(float(bounds_size.y) / 2.0)
	var max_z: int = global_center.y + floori(float(bounds_size.y) / 2.0)
	
	for gx: int in range(min_x, max_x + 1):
		for gz: int in range(min_z, max_z + 1):
			_sculpt_vertical_column(chunk, offset, gx, gz)


func _sculpt_vertical_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var dist_x: int = abs(gx - global_center.x)
	var dist_z: int = abs(gz - global_center.y)
	
	_sculpt_oasis_pool(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_pyramid_body(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_apex_beacon(chunk, offset, gx, gz, dist_x, dist_z)


func _sculpt_oasis_pool(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	for gy: int in range(0, 32):
		var ly: int = gy - offset.y
		if not chunk.is_within_bounds(gx - offset.x, ly, gz - offset.z): continue
		
		if gy < BASE_ALTITUDE_Y - 3:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE)
		elif gy < BASE_ALTITUDE_Y:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.SAND)
		elif gy == BASE_ALTITUDE_Y:
			_set_oasis_surface_block(chunk, offset, gx, ly, gz, dx, dz)
		else:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.AIR)


func _set_oasis_surface_block(chunk: Chunk, offset: Vector3i, gx: int, ly: int, gz: int, dx: int, dz: int) -> void:
	var is_pool: bool = (dx <= OASIS_POOL_LIMIT_X and dz <= OASIS_POOL_LIMIT_Z) or (dz <= OASIS_POOL_LIMIT_X and dx <= OASIS_POOL_LIMIT_Z)
	var is_pyramid: bool = (dx <= PYRAMID_BASE_RADIUS and dz <= PYRAMID_BASE_RADIUS)
	
	var type := BlockType.Type.SAND
	if is_pool and not is_pyramid:
		type = BlockType.Type.WATER
	elif is_pyramid:
		type = BlockType.Type.STONE
		
	chunk.set_block(gx - offset.x, ly, gz - offset.z, type)


func _sculpt_pyramid_body(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	for step_y: int in range(1, PYRAMID_HEIGHT + 1):
		var current_y: int = BASE_ALTITUDE_Y + step_y
		var current_radius: int = PYRAMID_BASE_RADIUS - step_y + 1
		
		if dx <= current_radius and dz <= current_radius:
			var is_casing: bool = (dx == current_radius or dz == current_radius)
			if is_casing:
				_sculpt_outer_casing(chunk, offset, gx, gz, current_y, step_y)
			else:
				_sculpt_inner_chambers(chunk, offset, gx, gz, current_y, step_y, dx, dz)


func _sculpt_outer_casing(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, step_y: int) -> void:
	var center_z: int = global_center.y
	var current_radius: int = PYRAMID_BASE_RADIUS - step_y + 1
	var is_entrance: bool = (gz == center_z + current_radius) and (abs(gx - global_center.x) <= 2) and (step_y <= 4)
	
	if is_entrance:
		return
		
	var type := BlockType.Type.RED_SAND if (gx + gz) % 2 == 0 else BlockType.Type.OAK_PLANKS
	set_global_block(chunk, offset, gx, cy, gz, type)


func _sculpt_inner_chambers(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int) -> void:
	var is_inner_sanctuary: bool = (dx <= RADIUS_INNER_SANCTUARY and dz <= RADIUS_INNER_SANCTUARY)
	if is_inner_sanctuary:
		_sculpt_sanctuary_levels(chunk, offset, gx, gz, cy, wy, dx, dz)
	else:
		_sculpt_outer_corridors(chunk, offset, gx, gz, cy, wy, dx, dz)


func _sculpt_sanctuary_levels(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int) -> void:
	if wy <= LEVEL_HOLLOW_HALL:
		_build_hollow_hall(chunk, offset, gx, gz, cy, wy, dx, dz)
	elif wy == LEVEL_CEILING_DIVISION:
		_build_ceiling_division(chunk, offset, gx, gz, cy, dx, dz)
	elif wy <= LEVEL_MEZZANINE_CORRIDOR:
		_build_mezzanine(chunk, offset, gx, gz, cy, wy, dx, dz)
	elif wy == LEVEL_ROOFTOP_SLAB:
		_build_rooftop_slab(chunk, offset, gx, gz, cy)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_hollow_hall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int) -> void:
	var c_x := global_center.x
	var c_z := global_center.y
	if dx <= 1 and dz <= 1:
		var type := BlockType.Type.AIR
		if wy == 1: type = BlockType.Type.STONE
		elif wy == 2: type = BlockType.Type.BRICKS
		elif wy == 3: type = BlockType.Type.GLOWSTONE
		set_global_block(chunk, offset, gx, cy, gz, type)
	elif gz == c_z - 4:
		_build_hall_stairs(chunk, offset, gx, gz, cy, wy, c_x)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_hall_stairs(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, c_x: int) -> void:
	if gx >= c_x - 5 and gx <= c_x - 2:
		var step_req: int = gx - (c_x - 5) + 1
		var type := BlockType.Type.STONE if wy <= step_req else BlockType.Type.AIR
		set_global_block(chunk, offset, gx, cy, gz, type)
	elif gx >= c_x + 2 and gx <= c_x + 5:
		var step_req: int = (c_x + 5) - gx + 1
		var type := BlockType.Type.STONE if wy <= step_req else BlockType.Type.AIR
		set_global_block(chunk, offset, gx, cy, gz, type)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_ceiling_division(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, dx: int, dz: int) -> void:
	var c_x := global_center.x
	var c_z := global_center.y
	var is_stair: bool = (gz == c_z - 4) and (abs(gx - c_x) >= 2 and abs(gx - c_x) <= 5)
	var is_well: bool = (dx <= 3 and dz <= 3)
	
	var type := BlockType.Type.AIR if (is_stair or is_well) else BlockType.Type.OAK_PLANKS
	set_global_block(chunk, offset, gx, cy, gz, type)


func _build_mezzanine(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int) -> void:
	var c_x := global_center.x
	var c_z := global_center.y
	var is_fence: bool = (wy == 6) and (dx == 4 or dz == 4)
	var is_roof_stair: bool = (gz == c_z + 4) and (gx >= c_x - 3 and gx <= c_x + 2)
	
	if is_fence:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
	elif is_roof_stair:
		var step_req: int = gx - (c_x - 3) + 1
		var type := BlockType.Type.STONE if (wy - 5) <= step_req else BlockType.Type.AIR
		set_global_block(chunk, offset, gx, cy, gz, type)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_rooftop_slab(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int) -> void:
	var c_x := global_center.x
	var c_z := global_center.y
	var is_hatch: bool = (gz == c_z + 4) and (gx >= c_x + 1 and gx <= c_x + 2)
	
	var type := BlockType.Type.AIR if is_hatch else BlockType.Type.STONE
	set_global_block(chunk, offset, gx, cy, gz, type)


func _sculpt_outer_corridors(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int) -> void:
	var is_partition: bool = (dx == 6 or dz == 6)
	var c_x := global_center.x
	var c_z := global_center.y
	
	if is_partition:
		var is_door: bool = (gx == c_x or gz == c_z) and ((wy >= 1 and wy <= 3) or (wy >= 6 and wy <= 8))
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_door else BlockType.Type.STONE)
	else:
		_build_corridor_space(chunk, offset, gx, gz, cy, wy, c_x, c_z)


func _build_corridor_space(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, c_x: int, c_z: int) -> void:
	if wy <= LEVEL_HOLLOW_HALL:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
	elif wy == LEVEL_CEILING_DIVISION:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.OAK_PLANKS)
	elif wy <= LEVEL_MEZZANINE_CORRIDOR:
		var is_pedestal: bool = (gx < c_x + LIMIT_WEST_VAULT) and (gx == c_x - 9 and gz == c_z) and (wy == 6)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.BRICKS if is_pedestal else BlockType.Type.AIR)
	elif wy == LEVEL_ROOFTOP_SLAB:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _sculpt_apex_beacon(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	if dx <= 1 and dz <= 1:
		var cy_faro := BASE_ALTITUDE_Y + LEVEL_BEACON_FARO
		set_global_block(chunk, offset, gx, cy_faro, gz, BlockType.Type.STONE)
		if dx == 0 and dz == 0:
			var cy_crown := BASE_ALTITUDE_Y + LEVEL_BEACON_CROWN
			set_global_block(chunk, offset, gx, cy_crown, gz, BlockType.Type.GLOWSTONE)


func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	if chunk_pos.x == -10 and chunk_pos.z == 15:
		var chest_pos_x := float(global_center.x - 9) + 0.5 
		var chest_pos_y := float(BASE_ALTITUDE_Y + 7)       
		var chest_pos_z := float(global_center.y) + 0.5     
		entities.append({"mob_id": 200, "pos": Vector3(chest_pos_x, chest_pos_y, chest_pos_z)})
		
		var mummy_y := float(BASE_ALTITUDE_Y + 1)
		entities.append({"mob_id": 10, "pos": Vector3(float(global_center.x) + 0.5, mummy_y, float(global_center.y - 4) + 0.5)}) 
		entities.append({"mob_id": 10, "pos": Vector3(float(global_center.x - 9) + 0.5, mummy_y, float(global_center.y + 4) + 0.5)}) 
	return entities
