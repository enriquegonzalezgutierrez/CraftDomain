# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/EmeraldLoopMegaStructure.gd
# Description: Handcrafted fixed landmark for the Emerald Zone.
#              Sculpts a giant checkered loop archway, speed track, and acts as 
#              a fast-travel teleport destination on the tactical world map.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EmeraldLoopMegaStructure
extends IMegaStructure

const LOOP_RADIUS: int = 14
const BASE_ALTITUDE_Y: int = 12


func _init() -> void:
	# Fixed coordinates in the high-speed Emerald Zone sector
	global_center = Vector2i(300, 300)
	bounds_size = Vector2i(40, 40)


func get_name() -> String:
	return "STRUCTURE_EMERALD_LOOP"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var center_x := global_center.x
	var center_z := global_center.y
	
	var min_x := center_x - floori(float(bounds_size.x) / 2.0)
	var max_x := center_x + floori(float(bounds_size.x) / 2.0)
	var min_z := center_z - floori(float(bounds_size.y) / 2.0)
	var max_z := center_z + floori(float(bounds_size.y) / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			_sculpt_structure_column(chunk, offset, gx, gz, center_x, center_z)


func _sculpt_structure_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int, center_x: int, center_z: int) -> void:
	var dist_x := abs(gx - center_x)
	var dist_z := abs(gz - center_z)
	
	_sculpt_checkered_foundation(chunk, offset, gx, gz, dist_x, dist_z)
	_sculpt_loop_archway(chunk, offset, gx, gz, dist_x, dist_z)


func _sculpt_checkered_foundation(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int) -> void:
	if dist_x <= LOOP_RADIUS and dist_z <= LOOP_RADIUS:
		for gy in range(0, BASE_ALTITUDE_Y + 1):
			var ly := gy - offset.y
			if not chunk.is_within_bounds(gx - offset.x, ly, gz - offset.z):
				continue
				
			if gy < BASE_ALTITUDE_Y:
				chunk.set_block(gx - offset.x, ly, gz - offset.z, BlockType.Type.STONE)
			elif gy == BASE_ALTITUDE_Y:
				# Checkered soil block pattern (Road / Grass combination)
				var is_checkered := (gx + gz) % 2 == 0
				var soil_type := BlockType.Type.ROAD if is_checkered else BlockType.Type.GRASS
				chunk.set_block(gx - offset.x, ly, gz - offset.z, soil_type)


func _sculpt_loop_archway(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_x: int, dist_z: int) -> void:
	# Sculpt track pillars
	if dist_x == 8 and dist_z <= 2:
		for wy in range(1, 10):
			var cy := BASE_ALTITUDE_Y + wy
			set_global_block(chunk, offset, gx, cy, gz, BlockType.Type.OAK_PLANKS)
			
	# Cross arch overhead at Y = BASE_ALTITUDE_Y + 10
	if dist_x <= 8 and dist_z <= 2:
		var arch_y := BASE_ALTITUDE_Y + 10
		set_global_block(chunk, offset, gx, arch_y, gz, BlockType.Type.GLOWSTONE if dist_x == 0 else BlockType.Type.OAK_PLANKS)
