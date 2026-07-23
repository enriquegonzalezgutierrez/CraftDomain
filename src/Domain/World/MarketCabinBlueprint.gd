# ==============================================================================
# Pathfile: res://src/Domain/World/MarketCabinBlueprint.gd
# Description: Concrete Structure Blueprint constructing village market stalls 
#              with slope-adaptive foundations and striped canopy roofs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MarketCabinBlueprint
extends IStructureBlueprint

const WIDTH: int = 4
const DEPTH: int = 4


## Concrete Contract: Returns the unique structure ID (8) matching the old Market Cabin
func get_structure_id() -> int:
	return 8


## Concrete Contract: Constructs a village merchant cabin anchored to the ground
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	_build_adaptive_foundation(chunk, start_x, start_z, ground_y)
	_build_corner_pillars(chunk, start_x, start_z, ground_y)
	_build_front_counter(chunk, start_x, start_z, ground_y)
	_build_canopy_roof(chunk, start_x, start_z, ground_y)


func _build_adaptive_foundation(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for x: int in range(WIDTH):
		var lx: int = start_x + x
		for z: int in range(DEPTH):
			var lz: int = start_z + z
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz) and chunk.get_block(lx, sy, lz) != BlockType.Type.AIR:
					real_ground_y = sy
					break
			for col_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, col_y, lz):
					chunk.set_block(lx, col_y, lz, BlockType.Type.STONE)


func _build_corner_pillars(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for y: int in range(1, 4):
		var ly: int = ground_y + y
		if chunk.is_within_bounds(start_x, ly, start_z): chunk.set_block(start_x, ly, start_z, BlockType.Type.WOOD)
		if chunk.is_within_bounds(start_x + WIDTH - 1, ly, start_z): chunk.set_block(start_x + WIDTH - 1, ly, start_z, BlockType.Type.WOOD)
		if chunk.is_within_bounds(start_x, ly, start_z + DEPTH - 1): chunk.set_block(start_x, ly, start_z + DEPTH - 1, BlockType.Type.WOOD)
		if chunk.is_within_bounds(start_x + WIDTH - 1, ly, start_z + DEPTH - 1): chunk.set_block(start_x + WIDTH - 1, ly, start_z + DEPTH - 1, BlockType.Type.WOOD)


func _build_front_counter(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var counter_y: int = ground_y + 1
	for cx: int in range(1, WIDTH - 1):
		var lx: int = start_x + cx
		if chunk.is_within_bounds(lx, counter_y, start_z):
			chunk.set_block(lx, counter_y, start_z, BlockType.Type.WOOD)


func _build_canopy_roof(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var roof_y: int = ground_y + 3
	for rx: int in range(WIDTH):
		var lx: int = start_x + rx
		for rz: int in range(DEPTH):
			var lz: int = start_z + rz
			if chunk.is_within_bounds(lx, roof_y, lz):
				var block_type := BlockType.Type.LEAVES if (rx % 2 == 0) else BlockType.Type.WOOD
				chunk.set_block(lx, roof_y, lz, block_type)
