# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/HarborCityMegaStructure.gd
# Description: HANDCRAFTED MULTI-DECK GALLEON & TWO-STORY SEAPORT TAVERN.
#              SOLID COMPLIANCE: Monolithic 'build_chunk' loop decomposed into 
#              isolated, SRP-compliant sculpt methods (< 20 lines each).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HarborCityMegaStructure
extends IMegaStructure

const WATER_LEVEL: int = 9
const DOCK_LEVEL: int = 11


func _init() -> void:
	global_center = Vector2i(-150, 0) 
	bounds_size = Vector2i(50, 40)


func get_name() -> String:
	return "STRUCTURE_HARBOR_CITY"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var b_min_x: int = global_center.x - floori(float(bounds_size.x) / 2.0)
	var b_max_x: int = global_center.x + floori(float(bounds_size.x) / 2.0)
	var b_min_z: int = global_center.y - floori(float(bounds_size.y) / 2.0)
	var b_max_z: int = global_center.y + floori(float(bounds_size.y) / 2.0)
	
	var bounds := Rect2i(b_min_x, b_min_z, bounds_size.x, bounds_size.y)
	
	for gx: int in range(b_min_x, b_max_x + 1):
		for gz: int in range(b_min_z, b_max_z + 1):
			_sculpt_vertical_column(chunk, offset, gx, gz, bounds)


func _sculpt_vertical_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int, bounds: Rect2i) -> void:
	var lx: int = gx - offset.x
	var lz: int = gz - offset.z
	
	_sculpt_cove_basin(chunk, lx, lz, offset.y, gx, gz, bounds)
	_sculpt_docks(chunk, offset, gx, gz)
	_sculpt_tavern(chunk, offset, gx, gz)
	_sculpt_galleon(chunk, offset, gx, gz)


func _sculpt_cove_basin(chunk: Chunk, lx: int, lz: int, oy: int, gx: int, gz: int, bounds: Rect2i) -> void:
	var is_border: bool = (gx == bounds.position.x or gx == bounds.end.x or gz == bounds.position.y or gz == bounds.end.y)
	
	for gy: int in range(0, 32):
		var ly: int = gy - oy
		if not chunk.is_within_bounds(lx, ly, lz): continue
		
		if gy < WATER_LEVEL - 3:
			chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
		elif gy < WATER_LEVEL:
			chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
		elif gy == WATER_LEVEL:
			chunk.set_block(lx, ly, lz, BlockType.Type.SAND if is_border else BlockType.Type.WATER)
		else:
			chunk.set_block(lx, ly, lz, BlockType.Type.AIR)


func _sculpt_docks(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	if not (gx >= -138 and gx <= -125 and gz >= -18 and gz <= 18): return
		
	for col_y: int in range(6, DOCK_LEVEL):
		set_global_block(chunk, offset, gx, col_y, gz, BlockType.Type.STONE)
		
	set_global_block(chunk, offset, gx, DOCK_LEVEL, gz, BlockType.Type.WOOD)
	
	if gx == -134 and abs(gz) == 12:
		set_global_block(chunk, offset, gx, DOCK_LEVEL + 1, gz, BlockType.Type.WOOD)
		if gz > 0:
			set_global_block(chunk, offset, gx, DOCK_LEVEL + 2, gz, BlockType.Type.WOOD)


func _sculpt_tavern(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	if not (gx >= -138 and gx <= -128 and gz >= -16 and gz <= -4): return
		
	var dist_x: int = gx - (-133)
	var dist_z: int = gz - (-10)
	var is_wall: bool = (gx == -138 or gx == -128 or gz == -16 or gz == -4)
	var is_door: bool = (gz == -4) and (gx == -133)
	
	for wy: int in range(1, 13):
		var cy: int = DOCK_LEVEL + wy
		if is_wall:
			_build_tavern_wall(chunk, offset, gx, gz, cy, wy, dist_x, dist_z, is_door)
		else:
			_build_tavern_interior(chunk, offset, gx, gz, cy, wy)
			
	set_global_block(chunk, offset, gx, DOCK_LEVEL + 13, gz, BlockType.Type.OAK_PLANKS)


func _build_tavern_wall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dx: int, dz: int, is_door: bool) -> void:
	if is_door and wy <= 3: return
	var is_window: bool = (wy == 3 or wy == 9) and (abs(dx) == 3 or abs(dz) == 4)
	var b_type := BlockType.Type.GLASS if is_window else BlockType.Type.STONE
	set_global_block(chunk, offset, gx, cy, gz, b_type)


func _build_tavern_interior(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if wy <= 5:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
	elif wy == 6:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.OAK_PLANKS)
	elif wy <= 12:
		_build_tavern_upper_floor(chunk, offset, gx, gz, cy, wy)


func _build_tavern_upper_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if gz == -10:
		var is_door: bool = (gx == -135 and wy <= 9)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_door else BlockType.Type.STONE)
	elif gx == -131:
		var is_door: bool = (gz == -7 or gz == -13) and wy <= 9
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_door else BlockType.Type.STONE)
	else:
		var is_bed: bool = (gx == -136 or gx == -135) and (gz == -14 or gz == -13) and wy == 7
		var is_pillow: bool = (gx == -136 or gx == -135) and (gz == -15) and wy == 8
		if is_bed: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
		elif is_pillow: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.CLOUD)
		else: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _sculpt_galleon(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	if not (gx >= -168 and gx <= -144 and gz >= -5 and gz <= 5): return
		
	var ship_x: int = gx - (-156) 
	var bow_taper: float = float(abs(gz)) / 5.0
	var hull_limit: float = 12.0 - (bow_taper * 4.0)
	
	if float(abs(ship_x)) > hull_limit: return
		
	for wy in range(WATER_LEVEL, WATER_LEVEL + 4):
		set_global_block(chunk, offset, gx, wy, gz, BlockType.Type.AIR)
		
	_build_cargo_hold(chunk, offset, gx, gz, ship_x, hull_limit)
	_build_main_deck(chunk, offset, gx, gz, ship_x)
	_build_quarterdeck(chunk, offset, gx, gz, ship_x, hull_limit)
	_build_masts(chunk, offset, gx, gz, ship_x)


func _build_cargo_hold(chunk: Chunk, offset: Vector3i, gx: int, gz: int, ship_x: int, hull_limit: float) -> void:
	for gy: int in range(6, DOCK_LEVEL):
		var is_hull: bool = (gy == 6) or (float(abs(ship_x)) > hull_limit - 1.0) or abs(gz) == 5
		if is_hull:
			set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
		else:
			var is_bunk: bool = (ship_x <= -5 and ship_x >= -8) and (abs(gz) == 3) and (gy == 7)
			set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.CLOUD if is_bunk else BlockType.Type.AIR)


func _build_main_deck(chunk: Chunk, offset: Vector3i, gx: int, gz: int, ship_x: int) -> void:
	var is_hatch: bool = (ship_x == -3 and gz == 0)
	if not is_hatch:
		set_global_block(chunk, offset, gx, DOCK_LEVEL, gz, BlockType.Type.OAK_PLANKS)
	else:
		for ly: int in range(7, DOCK_LEVEL + 1):
			set_global_block(chunk, offset, gx, ly, gz + 1, BlockType.Type.WOOD)


func _build_quarterdeck(chunk: Chunk, offset: Vector3i, gx: int, gz: int, ship_x: int, hull_limit: float) -> void:
	if ship_x >= 5 and ship_x <= 11 and abs(gz) <= 3:
		var is_wall: bool = (ship_x == 5 or ship_x == 11 or abs(gz) == 3)
		for wy: int in range(1, 6):
			var cy: int = DOCK_LEVEL + wy
			if is_wall:
				var is_win: bool = (ship_x == 11 and wy == 2)
				set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.GLASS if is_win else BlockType.Type.WOOD)
			else:
				var is_bed: bool = (ship_x >= 10 and ship_x <= 11) and (gz == -2) and wy == 1
				var is_pillow: bool = (ship_x == 11) and (gz == -2) and wy == 2
				if is_bed: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
				elif is_pillow: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.CLOUD)
				else: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
		set_global_block(chunk, offset, gx, DOCK_LEVEL + 5, gz, BlockType.Type.OAK_PLANKS)
	else:
		var is_rail: bool = (float(abs(ship_x)) > hull_limit - 1.0) or abs(gz) == 5
		if is_rail: set_global_block(chunk, offset, gx, DOCK_LEVEL + 1, gz, BlockType.Type.WOOD)


func _build_masts(chunk: Chunk, offset: Vector3i, gx: int, gz: int, ship_x: int) -> void:
	if gz != 0 or not (ship_x == -7 or ship_x == 1 or ship_x == 8): return
		
	for gy: int in range(DOCK_LEVEL + 1, DOCK_LEVEL + 17):
		set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
		
	for gy: int in range(DOCK_LEVEL + 4, DOCK_LEVEL + 13):
		var sail_radius: int = clampi(13 - (gy - DOCK_LEVEL), 1, 4)
		for sz: int in range(-sail_radius, sail_radius + 1):
			if sz != 0:
				set_global_block(chunk, offset, gx - 1, gy, gz + sz, BlockType.Type.CLOUD)


func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	if chunk_pos.x == -9 and chunk_pos.z == 0:
		entities.append({"mob_id": 100, "pos": Vector3(-138.5, 12.0, 3.5)})
		entities.append({"mob_id": 101, "pos": Vector3(-136.5, 12.0, -3.5)})
		entities.append({"mob_id": 102, "pos": Vector3(-131.5, 12.5, -4.5)})
	elif chunk_pos.x == -10 and chunk_pos.z == 0:
		entities.append({"mob_id": 102, "pos": Vector3(-150.5, 17.5, 0.5)})
		entities.append({"mob_id": 200, "pos": Vector3(-146.5, 17.5, -2.5)})
		entities.append({"mob_id": 100, "pos": Vector3(-162.5, 7.5, -3.5)})
	return entities
