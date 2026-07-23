# ==============================================================================
# Pathfile: res://src/Domain/World/CoalVeinBlueprint.gd
# Description: Concrete Ore Vein Strategy implementing a deterministic 3D random 
#              walk crawling algorithm to generate natural Coal deposits.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CoalVeinBlueprint
extends IOreVeinBlueprint

const ORE_TYPE := BlockType.Type.COAL_ORE
const REPLACEABLE_TYPE := BlockType.Type.STONE

# Coal vein size constraints
const MIN_STEPS: int = 6
const MAX_STEPS: int = 12
const BRANCH_CHANCE: float = 0.35


## Concrete Implementation: Returns the unique identifier for the Coal Vein (ID 1)
func get_vein_id() -> int:
	return 1


## Concrete Implementation: Returns the coal ore block type
func get_ore_block_type() -> BlockType.Type:
	return ORE_TYPE


## Concrete Implementation: Crawls through the chiseled stone grid, transforming stone blocks into coal veins
func grow_vein(chunk: Chunk, start_x: int, start_y: int, start_z: int, seed_hash: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash

	var main_trail := _crawl_main_trail(chunk, start_x, start_y, start_z, rng)
	_grow_secondary_branches(chunk, main_trail, rng)


func _crawl_main_trail(chunk: Chunk, start_x: int, start_y: int, start_z: int, rng: RandomNumberGenerator) -> Array[Vector3i]:
	var current_pos := Vector3i(start_x, start_y, start_z)
	var steps := rng.randi_range(MIN_STEPS, MAX_STEPS)
	var main_trail: Array[Vector3i] = []

	for i in range(steps):
		if not chunk.is_within_bounds(current_pos.x, current_pos.y, current_pos.z):
			break
			
		if chunk.get_block(current_pos.x, current_pos.y, current_pos.z) == REPLACEABLE_TYPE:
			chunk.set_block(current_pos.x, current_pos.y, current_pos.z, ORE_TYPE)
			main_trail.append(current_pos)
			
		current_pos += Vector3i(rng.randi_range(-1, 1), rng.randi_range(-1, 1), rng.randi_range(-1, 1))

	return main_trail


func _grow_secondary_branches(chunk: Chunk, main_trail: Array[Vector3i], rng: RandomNumberGenerator) -> void:
	for node: Vector3i in main_trail:
		if rng.randf() < BRANCH_CHANCE:
			var branch_dir := Vector3i(rng.randi_range(-1, 1), rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			var branch_pos := node + branch_dir
			if chunk.is_within_bounds(branch_pos.x, branch_pos.y, branch_pos.z) and chunk.get_block(branch_pos.x, branch_pos.y, branch_pos.z) == REPLACEABLE_TYPE:
				chunk.set_block(branch_pos.x, branch_pos.y, branch_pos.z, ORE_TYPE)
