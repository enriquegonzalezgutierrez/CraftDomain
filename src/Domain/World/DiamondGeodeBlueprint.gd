# ==============================================================================
# Pathfile: res://src/Domain/World/DiamondGeodeBlueprint.gd
# Description: Concrete Ore Vein Strategy implementing a spherical shell algorithm 
#              to generate Diamond Geodes with Glowstone cores.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DiamondGeodeBlueprint
extends IOreVeinBlueprint

const ORE_TYPE := BlockType.Type.DIAMOND_ORE
const CORE_TYPE := BlockType.Type.GLOWSTONE
const REPLACEABLE_TYPE := BlockType.Type.STONE

# Geode radius constraints
const MIN_RADIUS: float = 1.6
const MAX_RADIUS: float = 2.4


## Concrete Implementation: Returns the unique identifier for the Diamond Geode (ID 2)
func get_vein_id() -> int:
	return 2


## Concrete Implementation: Returns the diamond ore block type
func get_ore_block_type() -> BlockType.Type:
	return ORE_TYPE


## Concrete Implementation: Generates a small spherical crystal geode cluster replacing chiseled stone blocks
func grow_vein(chunk: Chunk, start_x: int, start_y: int, start_z: int, seed_hash: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash

	var radius := rng.randf_range(MIN_RADIUS, MAX_RADIUS)
	var r_int := int(ceil(radius))

	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			for z in range(-r_int, r_int + 1):
				_process_geode_voxel(chunk, Vector3i(start_x + x, start_y + y, start_z + z), Vector3i(x, y, z), radius)


func _process_geode_voxel(chunk: Chunk, target_pos: Vector3i, offset: Vector3i, radius: float) -> void:
	if not chunk.is_within_bounds(target_pos.x, target_pos.y, target_pos.z):
		return

	var dist_sq := float(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z)
	if dist_sq <= radius * radius:
		if chunk.get_block(target_pos.x, target_pos.y, target_pos.z) == REPLACEABLE_TYPE:
			var shell_inner_limit := (radius - 0.75) * (radius - 0.75)
			var target_block := ORE_TYPE if dist_sq > shell_inner_limit else CORE_TYPE
			chunk.set_block(target_pos.x, target_pos.y, target_pos.z, target_block)
