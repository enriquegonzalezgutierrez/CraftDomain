# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/StevesCabinMegaStructure.gd
# Description: HANDCRAFTED 2-STORY LOG CABIN, TRANSITABLE WINDMILL & VALLEY ARCH.
#              SOLID COMPLIANCE: Monolithic 'build_chunk' loop decomposed into 
#              isolated, SRP-compliant sculpt methods (< 20 lines each).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StevesCabinMegaStructure
extends IMegaStructure

const CABIN_WIDTH_HALF: int = 5    
const CABIN_LENGTH_HALF: int = 5
const TAV_DOCK_LEVEL: int = 10     


func _init() -> void:
	global_center = Vector2i(300, -300) 
	bounds_size = Vector2i(60, 60)


func get_name() -> String:
	return "BIOME_STEVES_CABIN"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var b_min_x: int = global_center.x - floori(float(bounds_size.x) / 2.0)
	var b_max_x: int = global_center.x + floori(float(bounds_size.x) / 2.0)
	var b_min_z: int = global_center.y - floori(float(bounds_size.y) / 2.0)
	var b_max_z: int = global_center.y + floori(float(bounds_size.y) / 2.0)
	
	for gx: int in range(b_min_x, b_max_x + 1):
		for gz: int in range(b_min_z, b_max_z + 1):
			_sculpt_vertical_column(chunk, offset, gx, gz)


func _sculpt_vertical_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var dist_x: int = gx - global_center.x
	var dist_z: int = gz - global_center.y
	
	_sculpt_valley_floor(chunk, offset, gx, gz)
	_sculpt_stone_archway(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_fountain(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_windmill(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_log_cabin(chunk, offset, gx, gz)
	_sculpt_wheat_farm(chunk, offset, gx, gz)


func _sculpt_valley_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	for gy: int in range(0, 32):
		var ly: int = gy - offset.y
		if not chunk.is_within_bounds(gx - offset.x, ly, gz - offset.z): continue
		
		if gy < TAV_DOCK_LEVEL:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.DIRT)
		elif gy == TAV_DOCK_LEVEL:
			var in_lodge: bool = (gx >= global_center.x - 12 and gx <= global_center.x - 2) and (gz >= global_center.y - 12 and gz <= global_center.y - 2)
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE if in_lodge else BlockType.Type.GRASS)
		else:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.AIR)


func _sculpt_stone_archway(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	if abs(dx) > 1 or abs(dz) > 20: return
		
	var arch_height: int = TAV_DOCK_LEVEL + 16 - floori(pow(float(dz), 2.0) / 25.0)
	for ay: int in range(arch_height - 3, arch_height + 1):
		if ay > TAV_DOCK_LEVEL + 1:
			set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.STONE)
			if ay == arch_height:
				set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.GRASS)
				if (gx + gz) % 3 == 0:
					set_global_block(chunk, offset, gx, ay + 1, gz, BlockType.Type.LEAVES)


func _sculpt_fountain(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	if abs(dx) > 2 or abs(dz) > 2: return
		
	var is_rim: bool = (abs(dx) == 2 or abs(dz) == 2)
	set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL + 1, gz, BlockType.Type.STONE if is_rim else BlockType.Type.WATER)
	
	if dx == 0 and dz == 0:
		set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL + 2, gz, BlockType.Type.STONE)
		set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL + 3, gz, BlockType.Type.STONE)
		for f_dx: int in range(-1, 2):
			for f_dz: int in range(-1, 2):
				if abs(f_dx) != abs(f_dz):
					set_global_block(chunk, offset, global_center.x + f_dx, TAV_DOCK_LEVEL + 3, global_center.y + f_dz, BlockType.Type.WATER)


func _sculpt_windmill(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dx: int, dz: int) -> void:
	if not (dx >= 11 and dx <= 15 and dz >= 9 and dz <= 13): return
		
	var is_wall: bool = (dx == 11 or dx == 15 or dz == 9 or dz == 13)
	var is_door: bool = (dz == 9) and (gx == global_center.x + 13)
	
	for wy: int in range(1, 15):
		var cy: int = TAV_DOCK_LEVEL + wy
		if is_wall:
			if is_door and wy <= 3: continue
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
		else:
			var b_type := BlockType.Type.OAK_PLANKS if (wy == 6 or wy == 11) else BlockType.Type.AIR
			set_global_block(chunk, offset, gx, cy, gz, b_type)
			
	if dx == 13 and dz == 9:
		_build_windmill_sails(chunk, offset, gx, gz)


func _build_windmill_sails(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var axle_y: int = TAV_DOCK_LEVEL + 11
	set_global_block(chunk, offset, gx, axle_y, gz - 1, BlockType.Type.WOOD)
	
	for i: int in range(1, 5):
		set_global_block(chunk, offset, gx + i, axle_y + i, gz - 1, BlockType.Type.CLOUD)
		set_global_block(chunk, offset, gx - i, axle_y + i, gz - 1, BlockType.Type.CLOUD)
		set_global_block(chunk, offset, gx + i, axle_y - i, gz - 1, BlockType.Type.CLOUD)
		set_global_block(chunk, offset, gx - i, axle_y - i, gz - 1, BlockType.Type.CLOUD)


func _sculpt_log_cabin(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var cx_min: int = global_center.x - 12
	var cx_max: int = global_center.x - 2
	var cz_min: int = global_center.y - 12
	var cz_max: int = global_center.y - 2
	
	if not (gx >= cx_min and gx <= cx_max and gz >= cz_min and gz <= cz_max): return
		
	var is_wall: bool = (gx == cx_min or gx == cx_max or gz == cz_min or gz == cz_max)
	var is_door: bool = (gz == cz_max) and (gx == global_center.x - 7)
	
	for wy: int in range(1, 13):
		var cy: int = TAV_DOCK_LEVEL + wy
		if is_wall:
			_build_cabin_wall(chunk, offset, gx, gz, cy, wy, cx_min, cz_min, is_door)
		else:
			_build_cabin_interior(chunk, offset, gx, gz, cy, wy, cx_min, cz_min)


func _build_cabin_wall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, cx: int, cz: int, is_door: bool) -> void:
	if is_door and wy <= 3: return
	var is_win: bool = (wy == 3 or wy == 9) and ((gx == global_center.x - 7 and gz == cz) or (gz == global_center.y - 7 and gx == cx))
	set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.GLASS if is_win else BlockType.Type.WOOD)


func _build_cabin_interior(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, cx: int, cz: int) -> void:
	if wy <= 5:
		var is_stair: bool = (gx == cx + 1) and (gz >= cz + 2 and gz <= cz + 6)
		var step_req: int = gz - (cz + 2) + 1
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (is_stair and wy <= step_req) else BlockType.Type.AIR)
	elif wy == 6:
		var is_landing: bool = (gx == cx + 1) and (gz >= cz + 5 and gz <= cz + 7)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_landing else BlockType.Type.OAK_PLANKS)
	elif wy <= 11:
		_build_cabin_upper_floor(chunk, offset, gx, gz, cy, wy, cx, cz)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.OAK_PLANKS)


func _build_cabin_upper_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, cx: int, cz: int) -> void:
	var is_div: bool = (gz == global_center.y - 7)
	if is_div:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if (gx == global_center.x - 5 and wy <= 9) else BlockType.Type.STONE)
	else:
		var is_bed: bool = (gx >= cx + 2 and gx <= cx + 3) and (gz == cz + 2) and (wy == 7)
		var is_pil: bool = (gx == cx + 2) and (gz == cz + 2) and (wy == 8)
		if is_bed: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.WOOD)
		elif is_pil: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.CLOUD)
		else: set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _sculpt_wheat_farm(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	var fx_min: int = global_center.x - 14
	var fx_max: int = global_center.x - 4
	var fz_min: int = global_center.y + 4
	var fz_max: int = global_center.y + 12
	
	if not (gx >= fx_min and gx <= fx_max and gz >= fz_min and gz <= fz_max): return
		
	var is_fence: bool = (gx == fx_min or gx == fx_max or gz == fz_min or gz == fz_max)
	if is_fence:
		if (gx + gz) % 2 == 0:
			set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL + 1, gz, BlockType.Type.WOOD)
	else:
		var is_canal: bool = (gx == global_center.x - 11 or gx == global_center.x - 8)
		if is_canal:
			set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL, gz, BlockType.Type.WATER)
		else:
			set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL, gz, BlockType.Type.DIRT)
			set_global_block(chunk, offset, gx, TAV_DOCK_LEVEL + 1, gz, BlockType.Type.CROP_RIPE)


func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	if chunk_pos.x == 18 and chunk_pos.z == -19:
		entities.append({"mob_id": 101, "pos": Vector3(302.5, 11.0, -297.5)})
		entities.append({"mob_id": 103, "pos": Vector3(292.5, 11.0, -292.5)})
		entities.append({"mob_id": 107, "pos": Vector3(300.5, 11.0, -300.5)})
		entities.append({"mob_id": 200, "pos": Vector3(293.5, 17.0, -308.5)})
	return entities
