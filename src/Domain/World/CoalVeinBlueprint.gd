# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Description: Concrete Ore Vein Strategy implementing a deterministic 3D random 
#              walk crawling algorithm to generate natural, branch-like Coal deposits.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                growth math, branching factor, and depth parameters of Coal.
#              - Liskov Substitution Principle (LSP): Fully satisfies the 
#                IOreVeinBlueprint contract signatures without modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/CoalVeinBlueprint.gd
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

	# 1. Initialize crawler coordinates and step budget
	var current_pos := Vector3i(start_x, start_y, start_z)
	var steps := rng.randi_range(MIN_STEPS, MAX_STEPS)
	
	# Keep track of generated nodes in this execution pass to spawn sub-branches
	var main_trail: Array[Vector3i] = []

	# 2. Main Crawling Pass: Walk in random 3D vectors
	for i in range(steps):
		if not chunk.is_within_bounds(current_pos.x, current_pos.y, current_pos.z):
			break
			
		# CAVERN PRESERVATION SHIELD:
		# Under DDD principles, veins only creep within existing stone matrix blocks,
		# completely avoiding corrupting carved caves, highways, or water bodies.
		var active_block := chunk.get_block(current_pos.x, current_pos.y, current_pos.z)
		if active_block == REPLACEABLE_TYPE:
			chunk.set_block(current_pos.x, current_pos.y, current_pos.z, ORE_TYPE)
			main_trail.append(current_pos)
			
		# Step randomly to an adjacent voxel (incorporating diagonal movements)
		current_pos.x += rng.randi_range(-1, 1)
		current_pos.y += rng.randi_range(-1, 1)
		current_pos.z += rng.randi_range(-1, 1)

	# 3. Branching Pass: Sprout brief secondary clusters from the main trail
	for node in main_trail:
		if rng.randf() < BRANCH_CHANCE:
			var branch_dir := Vector3i(
				rng.randi_range(-1, 1),
				rng.randi_range(-1, 1),
				rng.randi_range(-1, 1)
			)
			var branch_pos := node + branch_dir
			
			if chunk.is_within_bounds(branch_pos.x, branch_pos.y, branch_pos.z):
				if chunk.get_block(branch_pos.x, branch_pos.y, branch_pos.z) == REPLACEABLE_TYPE:
					chunk.set_block(branch_pos.x, branch_pos.y, branch_pos.z, ORE_TYPE)
