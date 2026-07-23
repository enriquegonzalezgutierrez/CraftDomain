# ==============================================================================
# Pathfile: res://src/Domain/World/DecayedTempleBlueprint.gd
# Description: Concrete Structure Blueprint implementing an adaptive Decayed Temple
#              ruin with slope-conforming foundations and central altars.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DecayedTempleBlueprint
extends IStructureBlueprint

const BLOCK_PILLAR := BlockType.Type.BRICKS
const BLOCK_ROOF := BlockType.Type.STONE
const BLOCK_ALTAR := BlockType.Type.GLOWSTONE
const BLOCK_DECOR := BlockType.Type.STONE_SLAB_BOTTOM

const TEMPLE_SIZE: int = 5 
const ROOF_HEIGHT_OFFSET: int = 4 


## Concrete Implementation: Returns the unique structure ID for the Decayed Temple (ID 15)
func get_structure_id() -> int:
	return 15


## Concrete Implementation: Builds an adaptive decayed temple ruin, adjusting columns to slopes
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var coord_hash: int = abs(start_x * 93856093 ^ start_z * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = coord_hash

	var roof_y: int = ground_y + ROOF_HEIGHT_OFFSET

	var columns: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(TEMPLE_SIZE - 1, 0),
		Vector2i(0, TEMPLE_SIZE - 1), Vector2i(TEMPLE_SIZE - 1, TEMPLE_SIZE - 1)
	]

	for offset: Vector2i in columns:
		_build_adaptive_column(chunk, start_x + offset.x, start_z + offset.y, roof_y)

	_build_roof_frames(chunk, start_x, start_z, roof_y, rng)
	_build_central_altar(chunk, start_x, start_z, roof_y)


func _build_roof_frames(chunk: Chunk, start_x: int, start_z: int, roof_y: int, rng: RandomNumberGenerator) -> void:
	for i in range(1, TEMPLE_SIZE - 1):
		if rng.randf() < 0.80: _set_block_safe(chunk, start_x + i, roof_y, start_z, BLOCK_ROOF)
		if rng.randf() < 0.80: _set_block_safe(chunk, start_x + i, roof_y, start_z + TEMPLE_SIZE - 1, BLOCK_ROOF)
		if rng.randf() < 0.80: _set_block_safe(chunk, start_x, roof_y, start_z + i, BLOCK_ROOF)
		if rng.randf() < 0.80: _set_block_safe(chunk, start_x + TEMPLE_SIZE - 1, roof_y, start_z + i, BLOCK_ROOF)


func _build_central_altar(chunk: Chunk, start_x: int, start_z: int, roof_y: int) -> void:
	var center_x: int = start_x + 2
	var center_z: int = start_z + 2
	var center_ground_y: int = _find_local_ground_y(chunk, center_x, center_z, roof_y - 1)
	
	_set_block_safe(chunk, center_x, center_ground_y + 1, center_z, BLOCK_ALTAR)
	_set_block_safe(chunk, center_x - 1, center_ground_y + 1, center_z, BLOCK_DECOR)
	_set_block_safe(chunk, center_x + 1, center_ground_y + 1, center_z, BLOCK_DECOR)


func _build_adaptive_column(chunk: Chunk, lx: int, lz: int, roof_y: int) -> void:
	var local_ground_y: int = _find_local_ground_y(chunk, lx, lz, roof_y - 1)
	for cy in range(roof_y, local_ground_y, -1):
		_set_block_safe(chunk, lx, cy, lz, BLOCK_PILLAR)


func _find_local_ground_y(chunk: Chunk, lx: int, lz: int, start_scan_y: int) -> int:
	for y in range(start_scan_y, 0, -1):
		if chunk.is_within_bounds(lx, y, lz):
			var block: BlockType.Type = chunk.get_block(lx, y, lz)
			if block != BlockType.Type.AIR and block != BlockType.Type.WATER:
				return y
	return start_scan_y - 4


func _set_block_safe(chunk: Chunk, x: int, y: int, z: int, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(x, y, z):
		chunk.set_block(x, y, z, type)
