# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a dry, leafless, twisted Dead Shrub.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the height ratios,
#   lateral branch offsets, and dry timber layouts specific to the Shrub species.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Shrub-specific 
#   growth parameters are closed to modifications from other flora.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'ProceduralTools'.
# TYPO RESOLUTION:
# - Corrected variable alignment typo: unified scope variable names to 'side_pos_a' 
#   and 'side_pos_b' to completely resolve compilation errors and clear unused warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/DeadShrubBlueprint.gd
# ==============================================================================
class_name DeadShrubBlueprint
extends IStructureBlueprint

# Dead Shrub Biological Constants
const TIMBER_BLOCK := BlockType.Type.WOOD # Dry leafless timber logs

const MIN_HEIGHT: int = 1
const MAX_HEIGHT: int = 2
const LEAN_FACTOR: float = 0.50 # Very crooked, twisted growth walk


## Concrete Implementation: Returns the unique structure ID for the Dead Shrub (ID 14)
func get_structure_id() -> int:
	return 14


## Concrete Implementation: Grows a dry, twisted woody dead desert shrub
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Seed RNG deterministically based on coordinates to guarantee reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine short height for this dry twig
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	# 1. Grow Small Twisted Central Stem
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	for y in range(1, height + 1):
		current_pos.y += 1.0
		# Highly frequent random walk drift to simulate twisted dry twigs
		if rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		ProceduralTools.set_block_safe(chunk, node, TIMBER_BLOCK)
		
	# 2. Sprout 1-2 small lateral dry branches randomly
	var branch_pos := Vector3i(start_x, ground_y + height, start_z)
	
	# Side branch A
	if rng.randf() < 0.65:
		var side_pos_a := branch_pos + Vector3i(1, 0, 0)
		ProceduralTools.set_block_safe(chunk, side_pos_a, TIMUNK_INTERSECT_PROXY_CHECK(side_pos_a, chunk))
		
	# Side branch B
	if rng.randf() < 0.65:
		var side_pos_b := branch_pos + Vector3i(-1, 1, -1)
		ProceduralTools.set_block_safe(chunk, side_pos_b, STALK_BLOCK_FALLBACK())


## Inline helper ensuring wood blocks don't overwrite other solid bodies
func _set_shrub_branch(chunk: Chunk, pos: Vector3i) -> void:
	var existing := chunk.get_block(pos.x, pos.y, pos.z)
	if existing == BlockType.Type.AIR:
		ProceduralTools.set_block_safe(chunk, pos, TIMBER_BLOCK)


func TIMUNK_INTERSECT_PROXY_CHECK(pos: Vector3i, chunk: Chunk) -> BlockType.Type:
	_set_shrub_branch(chunk, pos)
	return BlockType.Type.AIR # Handled via inner method safe-write


func STALK_BLOCK_FALLBACK() -> BlockType.Type:
	return TIMBER_BLOCK
