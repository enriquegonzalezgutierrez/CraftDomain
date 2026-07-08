# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Description: Concrete Structure Blueprint implementing an adaptive Decayed Temple
#              ruin. Automatically scales column heights downwards based on
#              terrain slopes to prevent floating structures on hillsides.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                adaptive mathematical structural layout of the Decayed Temple.
#              - Liskov Substitution Principle (LSP): Fully implements the 
#                IStructureBlueprint interface contract.
#              GD位 COMPILATION FIX:
#              - Fully typed Array[Vector2i] and iterators statically to resolve
#                type-inference and untyped variant warnings in Godot 4.
#              CONTRACT CORRECTION:
#              - Corrected interface contract signature to 'get_structure_id()'
#                to properly implement IStructureBlueprint (fixed vein fallback assertion).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/DecayedTempleBlueprint.gd
# ==============================================================================
class_name DecayedTempleBlueprint
extends IStructureBlueprint

const BLOCK_PILLAR := BlockType.Type.BRICKS
const BLOCK_ROOF := BlockType.Type.STONE
const BLOCK_ALTAR := BlockType.Type.GLOWSTONE
const BLOCK_DECOR := BlockType.Type.STONE_SLAB_BOTTOM

const TEMPLE_SIZE: int = 5 # 5x5 layout
const ROOF_HEIGHT_OFFSET: int = 4 # Height of the roof above the center ground Y


## Concrete Implementation: Returns the unique structure ID for the Decayed Temple (ID 15)
func get_structure_id() -> int:
	return 15


## Concrete Implementation: Builds an adaptive decayed temple ruin, adjusting columns to slopes
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Seed local RNG based on coordinates for deterministic decay patterns
	var coord_hash: int = abs(start_x * 93856093 ^ start_z * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = coord_hash

	var roof_y: int = ground_y + ROOF_HEIGHT_OFFSET

	# 2. Adaptive Column Placements at the 4 corners of the 5x5 perimeter
	var columns: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(TEMPLE_SIZE - 1, 0),
		Vector2i(0, TEMPLE_SIZE - 1),
		Vector2i(TEMPLE_SIZE - 1, TEMPLE_SIZE - 1)
	]

	for offset: Vector2i in columns:
		var lx: int = start_x + offset.x
		var lz: int = start_z + offset.y
		_build_adaptive_column(chunk, lx, lz, roof_y)

	# 3. Build Broken Arch Roof Connectors (horizontal frames)
	for i in range(1, TEMPLE_SIZE - 1):
		# Only place blocks if they survive the decay check (80% survival chance)
		if rng.randf() < 0.80:
			_set_block_safe(chunk, start_x + i, roof_y, start_z, BLOCK_ROOF)
		if rng.randf() < 0.80:
			_set_block_safe(chunk, start_x + i, roof_y, start_z + TEMPLE_SIZE - 1, BLOCK_ROOF)
		if rng.randf() < 0.80:
			_set_block_safe(chunk, start_x, roof_y, start_z + i, BLOCK_ROOF)
		if rng.randf() < 0.80:
			_set_block_safe(chunk, start_x + TEMPLE_SIZE - 1, roof_y, start_z + i, BLOCK_ROOF)

	# 4. Central Altar Altar (Centered at X+2, Z+2)
	var center_x: int = start_x + 2
	var center_z: int = start_z + 2
	
	# Find ground height at center
	var center_ground_y: int = _find_local_ground_y(chunk, center_x, center_z, roof_y - 1)
	
	# Altar Pedestal
	_set_block_safe(chunk, center_x, center_ground_y + 1, center_z, BLOCK_ALTAR)
	# Decorative slab steps flanking the altar
	_set_block_safe(chunk, center_x - 1, center_ground_y + 1, center_z, BLOCK_DECOR)
	_set_block_safe(chunk, center_x + 1, center_ground_y + 1, center_z, BLOCK_DECOR)


## Internal Helper: Scans downward from the roof level to grow a column to the terrain level
func _build_adaptive_column(chunk: Chunk, lx: int, lz: int, roof_y: int) -> void:
	var local_ground_y: int = _find_local_ground_y(chunk, lx, lz, roof_y - 1)
	
	# Build column from roof level down to local ground level
	for cy in range(roof_y, local_ground_y, -1):
		_set_block_safe(chunk, lx, cy, lz, BLOCK_PILLAR)


## Internal Helper: Performs a downward vertical column search to find the highest non-air block
func _find_local_ground_y(chunk: Chunk, lx: int, lz: int, start_scan_y: int) -> int:
	var fallback_y: int = start_scan_y - 4
	
	# Scan down to find first solid terrain surface
	for y in range(start_scan_y, 0, -1):
		if chunk.is_within_bounds(lx, y, lz):
			var block: BlockType.Type = chunk.get_block(lx, y, lz)
			if block != BlockType.Type.AIR and block != BlockType.Type.WATER:
				return y
				
	return fallback_y


## Internal Helper: Safely sets block verifying chunk boundaries
func _set_block_safe(chunk: Chunk, x: int, y: int, z: int, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(x, y, z):
		chunk.set_block(x, y, z, type)
