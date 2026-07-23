# ==============================================================================
# Pathfile: res://src/Domain/World/GeothermalVentBlueprint.gd
# Description: Concrete Structure Blueprint implementing a procedural Geothermal 
#              Lava Vent with basalt rim craters and volcanic lava tubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GeothermalVentBlueprint
extends IStructureBlueprint

const BLOCK_RIM := BlockType.Type.STONE
const BLOCK_ACCENT := BlockType.Type.COAL_ORE
const BLOCK_FLUID := BlockType.Type.LAVA

const CRATER_RADIUS: float = 2.4


## Concrete Implementation: Returns the unique structure ID for the Geothermal Vent (ID 16)
func get_structure_id() -> int:
	return 16


## Concrete Implementation: Sculpts the circular volcanic crater and carves a deep subterranean lava shaft
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var coord_hash: int = abs(start_x * 73856093 ^ start_z * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = coord_hash

	var r_int: int = int(ceil(CRATER_RADIUS))

	for x: int in range(-r_int, r_int + 1):
		for z: int in range(-r_int, r_int + 1):
			_sculpt_crater_cell(chunk, start_x + x, start_z + z, ground_y, x, z, rng)


func _sculpt_crater_cell(chunk: Chunk, lx: int, lz: int, ground_y: int, x: int, z: int, rng: RandomNumberGenerator) -> void:
	if not chunk.is_within_bounds(lx, ground_y, lz):
		return

	var dist_sq := float(x * x + z * z)
	if dist_sq > CRATER_RADIUS * CRATER_RADIUS:
		return

	if dist_sq < 1.5:
		for cy: int in range(ground_y + 1, ground_y - 4, -1):
			_set_block_safe(chunk, lx, cy, lz, BLOCK_FLUID)
	else:
		_set_block_safe(chunk, lx, ground_y, lz, BLOCK_RIM)
		var border_type := BLOCK_RIM if rng.randf() < 0.70 else BLOCK_ACCENT
		_set_block_safe(chunk, lx, ground_y + 1, lz, border_type)
		if dist_sq > (CRATER_RADIUS - 0.7) * (CRATER_RADIUS - 0.7):
			_set_block_safe(chunk, lx, ground_y + 2, lz, BlockType.Type.AIR)


func _set_block_safe(chunk: Chunk, x: int, y: int, z: int, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(x, y, z):
		chunk.set_block(x, y, z, type)
