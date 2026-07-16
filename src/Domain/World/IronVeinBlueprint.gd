# ==============================================================================
# Pathfile: res://src/Domain/World/IronVeinBlueprint.gd
# Description: Concrete Ore Vein Strategy implementing a deterministic 3D random 
#              walk crawling algorithm to generate raw Iron Ore deposits.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the growth math,
#   branching factor, and depth parameters of Iron.
# - Liskov Substitution Principle (LSP): Fully satisfies the 
#   IOreVeinBlueprint contract signatures without modifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IronVeinBlueprint
extends IOreVeinBlueprint

const ORE_TYPE := 31 # Equivalent to BlockType.Type.IRON_ORE
const REPLACEABLE_TYPE := BlockType.Type.STONE

# Iron vein size constraints
const MIN_STEPS: int = 5
const MAX_STEPS: int = 10
const BRANCH_CHANCE: float = 0.30


## Concrete Implementation: Returns the unique identifier for the Iron Vein (ID 3)
func get_vein_id() -> int:
	return 3


## Concrete Implementation: Returns the iron ore block type
func get_ore_block_type() -> BlockType.Type:
	return ORE_TYPE as BlockType.Type


## Concrete Implementation: Crawls through the stone grid, transforming stone blocks into iron veins
func grow_vein(chunk: Chunk, start_x: int, start_y: int, start_z: int, seed_hash: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash

	var current_pos := Vector3i(start_x, start_y, start_z)
	var steps := rng.randi_range(MIN_STEPS, MAX_STEPS)
	var main_trail: Array[Vector3i] = []

	# Main Crawling Pass: Walk in random 3D vectors
	for i in range(steps):
		if not chunk.is_within_bounds(current_pos.x, current_pos.y, current_pos.z):
			break
			
		var active_block := chunk.get_block(current_pos.x, current_pos.y, current_pos.z)
		if active_block == REPLACEABLE_TYPE:
			chunk.set_block(current_pos.x, current_pos.y, current_pos.z, ORE_TYPE as BlockType.Type)
			main_trail.append(current_pos)
			
		# Vertical-tending step to simulate iron fissures
		current_pos.x += rng.randi_range(-1, 1)
		current_pos.y += rng.randi_range(0, 1) # Prefer upward/vertical crawling
		current_pos.z += rng.randi_range(-1, 1)

	# Branching Pass: Sprout brief secondary clusters
	for node in main_trail:
		if rng.randf() < BRANCH_CHANCE:
			_sprout_secondary_branch(chunk, node, rng)


func _sprout_secondary_branch(chunk: Chunk, origin: Vector3i, rng: RandomNumberGenerator) -> void:
	var branch_dir := Vector3i(
		rng.randi_range(-1, 1),
		rng.randi_range(-1, 1),
		rng.randi_range(-1, 1)
	)
	var branch_pos := origin + branch_dir
	
	if chunk.is_within_bounds(branch_pos.x, branch_pos.y, branch_pos.z):
		if chunk.get_block(branch_pos.x, branch_pos.y, branch_pos.z) == REPLACEABLE_TYPE:
			chunk.set_block(branch_pos.x, branch_pos.y, branch_pos.z, ORE_TYPE as BlockType.Type)
