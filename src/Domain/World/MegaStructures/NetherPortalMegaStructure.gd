# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/NetherPortalMegaStructure.gd
# Description: Handcrafted two-story volcanic brick citadel and portal sanctuary.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the 
#   geometric block-sculpting algorithms, completely decoupled from
#   entity spawning, registries, and raw database IDs.
# - Method Size Limits (Rule 4.2): Decomposed into modular, typesafe helper 
#   initializers kept strictly < 20 lines of code.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetherPortalMegaStructure
extends IMegaStructure

const OUTPOST_RADIUS: int = 18     
const SANCTUARY_HALF_SIZE: int = 8 


func _init() -> void:
	global_center = Vector2i(-300, -300) 
	bounds_size = Vector2i(50, 50)


func get_name() -> String:
	return "BIOME_NETHER_OUTPOST"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 8
	var b_min_x: int = global_center.x - floori(float(bounds_size.x) / 2.0)
	var b_max_x: int = global_center.x + floori(float(bounds_size.x) / 2.0)
	var b_min_z: int = global_center.y - floori(float(bounds_size.y) / 2.0)
	var b_max_z: int = global_center.y + floori(float(bounds_size.y) / 2.0)
	
	for gx in range(b_min_x, b_max_x + 1):
		for gz in range(b_min_z, b_max_z + 1):
			_sculpt_vertical_column(chunk, offset, gx, gz, base_y)


func _sculpt_vertical_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int, base_y: int) -> void:
	var dist_x: int = abs(gx - global_center.x)
	var dist_z: int = abs(gz - global_center.y)
	
	_sculpt_volcanic_moats(chunk, offset, gx, gz, dist_x, dist_z, base_y)
	_sculpt_outer_ramparts(chunk, offset, gx, gz, dist_x, dist_z, base_y)
	_sculpt_obsidian_towers(chunk, offset, gx, gz, base_y)
	_sculpt_sanctuary(chunk, offset, gx, gz, dist_x, dist_z, base_y)


func _sculpt_volcanic_moats(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int, base_y: int) -> void:
	for gy: int in range(0, 32):
		var ly: int = gy - offset.y
		if not chunk.is_within_bounds(gx - offset.x, ly, gz - offset.z): continue
		
		if gy < base_y - 2:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE)
		elif gy < base_y:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.RED_SAND)
		elif gy == base_y:
			var is_lava: bool = (dist_x == 15 or dist_x == 16 or dist_z == 15 or dist_z == 16) and (dist_x <= 16 and dist_z <= 16)
			var is_bridge: bool = (abs(gx - global_center.x) <= 2) and (dist_z >= 14 and dist_z <= 17)
			var b_type := BlockType.Type.LAVA if (is_lava and not is_bridge) else BlockType.Type.RED_SAND
			chunk.set_block(gx - offset.x, ly, gz - offset.z, b_type)
		else:
			chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.AIR)


func _sculpt_outer_ramparts(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int, base_y: int) -> void:
	var is_wall: bool = (dist_x == OUTPOST_RADIUS and dist_z <= OUTPOST_RADIUS) or (dist_z == OUTPOST_RADIUS and dist_x <= OUTPOST_RADIUS)
	if not is_wall: return
		
	var is_gate: bool = (gz == global_center.y + OUTPOST_RADIUS) and (dist_x <= 2)
	for wy: int in range(1, 8):
		var cy: int = base_y + wy
		if is_gate and wy <= 4: continue
			
		if wy == 6:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
		elif wy == 7:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (gx + gz) % 2 == 0 else BlockType.Type.AIR)
		else:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)


func _sculpt_obsidian_towers(chunk: Chunk, offset: Vector3i, gx: int, gz: int, base_y: int) -> void:
	var tower_rad: int = 4
	var is_tower := false
	var tx: int = 0
	var tz: int = 0
	
	if abs(gx - (global_center.x - OUTPOST_RADIUS)) <= tower_rad and abs(gz - (global_center.y - OUTPOST_RADIUS)) <= tower_rad:
		is_tower = true; tx = global_center.x - OUTPOST_RADIUS; tz = global_center.y - OUTPOST_RADIUS
	elif abs(gx - (global_center.x + OUTPOST_RADIUS)) <= tower_rad and abs(gz - (global_center.y - OUTPOST_RADIUS)) <= tower_rad:
		is_tower = true; tx = global_center.x + OUTPOST_RADIUS; tz = global_center.y - OUTPOST_RADIUS
	elif abs(gx - (global_center.x - OUTPOST_RADIUS)) <= tower_rad and abs(gz - (global_center.y + OUTPOST_RADIUS)) <= tower_rad:
		is_tower = true; tx = global_center.x - OUTPOST_RADIUS; tz = global_center.y + OUTPOST_RADIUS
	elif abs(gx - (global_center.x + OUTPOST_RADIUS)) <= tower_rad and abs(gz - (global_center.y + OUTPOST_RADIUS)) <= tower_rad:
		is_tower = true; tx = global_center.x + OUTPOST_RADIUS; tz = global_center.y + OUTPOST_RADIUS
		
	if is_tower:
		_build_obsidian_cylinder(chunk, offset, gx, gz, tx, tz, base_y, tower_rad)


func _build_obsidian_cylinder(chunk: Chunk, offset: Vector3i, gx: int, gz: int, tx: int, tz: int, base_y: int, tower_rad: int) -> void:
	var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
	if t_dist > float(tower_rad): return
		
	for wy: int in range(1, 16):
		var cy: int = base_y + wy
		var is_wall: bool = t_dist > float(tower_rad) - 1.5
		if is_wall:
			if wy == 15 and (gx + gz) % 2 == 0: continue
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
		else:
			var b_type := BlockType.Type.OAK_PLANKS if (wy == 6 or wy == 11) else BlockType.Type.AIR
			set_global_block(chunk, offset, gx, cy, gz, b_type)


func _sculpt_sanctuary(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int, base_y: int) -> void:
	if dist_x > SANCTUARY_HALF_SIZE or dist_z > SANCTUARY_HALF_SIZE: return
		
	var is_wall: bool = (dist_x == SANCTUARY_HALF_SIZE or dist_z == SANCTUARY_HALF_SIZE)
	var is_gate: bool = (gz == global_center.y + SANCTUARY_HALF_SIZE) and (dist_x <= 3)
	
	for wy: int in range(1, 16):
		var cy: int = base_y + wy
		if is_wall:
			_build_sanctuary_wall(chunk, offset, gx, gz, cy, wy, dist_x, dist_z, is_gate)
		else:
			_build_sanctuary_interior(chunk, offset, gx, gz, cy, wy, dist_x, dist_z)


func _build_sanctuary_wall(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, _wy: int, dx: int, dz: int, is_gate: bool) -> void:
	if is_gate and _wy <= 5: return
	var is_win: bool = (_wy == 3 or _wy == 10) and ((dx == SANCTUARY_HALF_SIZE and gz % 4 == 0) or (dz == SANCTUARY_HALF_SIZE and gx % 4 == 0))
	var b_type := BlockType.Type.GLASS if (is_win and not is_gate) else BlockType.Type.STONE
	set_global_block(chunk, offset, gx, cy, gz, b_type)


func _build_sanctuary_interior(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int, dist_x: int, dist_z: int) -> void:
	if dist_x <= 4 and dist_z <= 2:
		_build_portal_frame(chunk, offset, gx, gz, cy, wy)
	elif gz == global_center.y - 6:
		_build_sanctuary_stairs(chunk, offset, gx, gz, cy, wy)
	elif wy == 6:
		var is_landing: bool = (gz == global_center.y - 6) and (abs(gx - global_center.x) >= 5 and abs(gx - global_center.x) <= 7)
		var is_open: bool = (gz >= global_center.y - 3)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if (is_landing or is_open) else BlockType.Type.OAK_PLANKS)
	elif wy <= 11:
		_build_sanctuary_upper_suites(chunk, offset, gx, gz, cy, wy)
	elif wy == 12:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE)
	else:
		var is_edge: bool = (dist_x == SANCTUARY_HALF_SIZE - 1 or dist_z == SANCTUARY_HALF_SIZE - 1)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if (is_edge and wy == 13 and (gx + gz) % 2 == 0) else BlockType.Type.AIR)


func _build_portal_frame(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if gz == global_center.y and abs(gx - global_center.x) <= 4 and wy <= 8:
		var is_frame: bool = (abs(gx - global_center.x) == 4) or (wy == 1) or (wy == 8)
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if is_frame else BlockType.Type.NEON_MAGENTA)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_sanctuary_stairs(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if gx >= global_center.x - 7 and gx <= global_center.x - 5:
		var s_req: int = gx - (global_center.x - 7) + 1
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if wy <= s_req else BlockType.Type.AIR)
	elif gx >= global_center.x + 5 and gx <= global_center.x + 7:
		var s_req: int = (global_center.x + 7) - gx + 1
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.STONE if wy <= s_req else BlockType.Type.AIR)
	else:
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)


func _build_sanctuary_upper_suites(chunk: Chunk, offset: Vector3i, gx: int, gz: int, cy: int, wy: int) -> void:
	if gz == global_center.y - 3:
		var is_arch: bool = abs(gx - global_center.x) <= 1 and wy <= 9
		set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR if is_arch else BlockType.Type.STONE)
	else:
		if gx < global_center.x and gz < global_center.y - 3:
			var is_pedestal: bool = (gx == global_center.x - 6 and gz == global_center.y - 6) and (wy == 7)
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.BRICKS if is_pedestal else BlockType.Type.AIR)
		else:
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.AIR)
