# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/LithicLurkerLairMegaStructure.gd
# Description: Handcrafted boss arena for the Act I Boss (Lithic Lurker).
#              Carves a deep basalt crater, generates lava pools, and spawns 
#              the boss entity at fixed coordinates.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the 
#   geometric block-sculpting algorithms, completely decoupled from
#   entity spawning, registries, and raw database IDs.
# - Method Size Limits (Rule 4.2): Decomposed into modular, typesafe helper 
#   initializers kept strictly < 20 lines of code.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LithicLurkerLairMegaStructure
extends IMegaStructure

const ARENA_RADIUS: int = 12
const BASE_ALTITUDE_Y: int = 15


func _init() -> void:
	# Fixed coordinates in the Craggy Peaks (Act I)
	global_center = Vector2i(-100, 100) 
	bounds_size = Vector2i(30, 30)


func get_name() -> String:
	return "STRUCTURE_LITHIC_LURKER_LAIR"


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var center_x := global_center.x
	var center_z := global_center.y
	
	var min_x := center_x - floori(float(bounds_size.x) / 2.0)
	var max_x := center_x + floori(float(bounds_size.x) / 2.0)
	var min_z := center_z - floori(float(bounds_size.y) / 2.0)
	var max_z := center_z + floori(float(bounds_size.y) / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			_sculpt_arena_column(chunk, offset, gx, gz, center_x, center_z)


func _sculpt_arena_column(chunk: Chunk, offset: Vector3i, gx: int, gz: int, center_x: int, center_z: int) -> void:
	var dist_x := abs(gx - center_x)
	var dist_z := abs(gz - center_z)
	var dist_sq := float(dist_x * dist_x + dist_z * dist_z)
	var radius_sq := float(ARENA_RADIUS * ARENA_RADIUS)
	
	if dist_sq <= radius_sq:
		_clear_arena_airspace(chunk, offset, gx, gz)
		_build_arena_floor(chunk, offset, gx, gz, dist_sq)


func _clear_arena_airspace(chunk: Chunk, offset: Vector3i, gx: int, gz: int) -> void:
	for gy in range(BASE_ALTITUDE_Y + 1, 32):
		set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)


func _build_arena_floor(chunk: Chunk, offset: Vector3i, gx: int, gz: int, dist_sq: float) -> void:
	var floor_type := BlockType.Type.STONE
	
	# Create scattered lava pools near the center
	if dist_sq < 16.0 and (gx + gz) % 3 == 0:
		floor_type = BlockType.Type.LAVA
		
	set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y, gz, floor_type)
	
	# Solidify the foundation below the arena floor
	for gy in range(BASE_ALTITUDE_Y - 3, BASE_ALTITUDE_Y):
		set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.STONE)
