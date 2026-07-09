# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: MarketCabinBlueprint
# Description: OCP-compliant structure blueprint that procedurally constructs
#              village market stalls with an adaptive foundation system. It
#              scans underneath the base perimeter and grows support stone pillars
#              downwards until they anchor flat on solid terrain, avoiding any
#              hanging structures on hillsides and slopes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively handles the structural 
#   foundations and cosmetic canopy layout of market cabins.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 8, completely replacing the static template.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MarketCabinBlueprint.gd
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
	
	# ==========================================================================
	# 1. ADAPTIVE STONE FOUNDATIONS (Solves floating on slopes)
	# ==========================================================================
	for x: int in range(WIDTH):
		var lx: int = start_x + x
		for z: int in range(DEPTH):
			var lz: int = start_z + z
			
			# Scan downwards from ground_y to find real solid ground
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz):
					var check_block: BlockType.Type = chunk.get_block(lx, sy, lz)
					if check_block != BlockType.Type.AIR and check_block != BlockType.Type.WATER:
						real_ground_y = sy
						break
			
			# Grow stone column from real floor up to build foundation surface
			for col_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, col_y, lz):
					chunk.set_block(lx, col_y, lz, BlockType.Type.STONE)

	# ==========================================================================
	# 2. CORNER SUPPORT PILLARS (Wooden posts)
	# ==========================================================================
	for y: int in range(1, 4):
		var ly: int = ground_y + y
		
		# NW Pillar
		if chunk.is_within_bounds(start_x, ly, start_z):
			chunk.set_block(start_x, ly, start_z, BlockType.Type.WOOD)
		# NE Pillar
		if chunk.is_within_bounds(start_x + WIDTH - 1, ly, start_z):
			chunk.set_block(start_x + WIDTH - 1, ly, start_z, BlockType.Type.WOOD)
		# SW Pillar
		if chunk.is_within_bounds(start_x, ly, start_z + DEPTH - 1):
			chunk.set_block(start_x, ly, start_z + DEPTH - 1, BlockType.Type.WOOD)
		# SE Pillar
		if chunk.is_within_bounds(start_x + WIDTH - 1, ly, start_z + DEPTH - 1):
			chunk.set_block(start_x + WIDTH - 1, ly, start_z + DEPTH - 1, BlockType.Type.WOOD)

	# ==========================================================================
	# 3. FRONT COUNTER BARRIER (Wooden counters)
	# ==========================================================================
	var counter_y: int = ground_y + 1
	for cx: int in range(1, WIDTH - 1):
		var lx: int = start_x + cx
		if chunk.is_within_bounds(lx, counter_y, start_z):
			chunk.set_block(lx, counter_y, start_z, BlockType.Type.WOOD)

	# ==========================================================================
	# 4. STRIPED SUN-SHADE CANOPY (Roofs)
	# ==========================================================================
	var roof_y: int = ground_y + 3
	for rx: int in range(WIDTH):
		var lx: int = start_x + rx
		for rz: int in range(DEPTH):
			var lz: int = start_z + rz
			
			if chunk.is_within_bounds(lx, roof_y, lz):
				# Alternating green and brown fabric stripes
				var is_stripe: bool = (rx % 2 == 0)
				if is_stripe:
					chunk.set_block(lx, roof_y, lz, BlockType.Type.LEAVES)
				else:
					chunk.set_block(lx, roof_y, lz, BlockType.Type.WOOD)
