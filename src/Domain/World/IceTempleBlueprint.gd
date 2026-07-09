# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: IceTempleBlueprint
# Description: OCP-compliant structure blueprint that procedurally constructs
#              sacred hollow spires out of Blue Ice with adaptive foundations. 
#              It scans the polar hillsides to grow thick solid ice columns 
#              downwards to prevent structures from floating on glacier edges.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only manages the architectural 
#   hollow tower, window slits, and battlements of the Ice Temple.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 6, completely replacing the static template.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IceTempleBlueprint.gd
# ==============================================================================
class_name IceTempleBlueprint
extends IStructureBlueprint

const SIZE: int = 3
const TOWER_HEIGHT: int = 8


## Concrete Contract: Returns the unique structure ID (6) matching the old Ice Temple
func get_structure_id() -> int:
	return 6


## Concrete Contract: Builds a hollow polar spire adapted to snowy terrain slopes
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	
	# ==========================================================================
	# 1. ADAPTIVE POLAR FOUNDATIONS (Grows solid ice down to the bedrock)
	# ==========================================================================
	for x: int in range(SIZE):
		var lx: int = start_x + x
		for z: int in range(SIZE):
			var lz: int = start_z + z
			
			# Vertical column scan to find solid ground
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz):
					var check_block: BlockType.Type = chunk.get_block(lx, sy, lz)
					if check_block != BlockType.Type.AIR and check_block != BlockType.Type.WATER:
						real_ground_y = sy
						break
			
			# Fill downward foundation with Ice blocks (ID 10)
			for fill_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, fill_y, lz):
					chunk.set_block(lx, fill_y, lz, BlockType.Type.ICE)

	# ==========================================================================
	# 2. HOLLOW SPIRE WALLS (Height 8, with strategic arrow slits at Y+4 and Y+6)
	# ==========================================================================
	for y: int in range(1, TOWER_HEIGHT):
		var ly: int = ground_y + y
		
		for x: int in range(SIZE):
			var lx: int = start_x + x
			for z: int in range(SIZE):
				var lz: int = start_z + z
				
				var is_edge: bool = (x == 0 or x == SIZE - 1 or z == 0 or z == SIZE - 1)
				
				if is_edge:
					# Create arrow slits on upper levels (middle block of edge walls)
					var is_window: bool = (y == 4 or y == 6) and (x == 1 or z == 1)
					if is_window:
						if chunk.is_within_bounds(lx, ly, lz):
							chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						if chunk.is_within_bounds(lx, ly, lz):
							chunk.set_block(lx, ly, lz, BlockType.Type.ICE)
				else:
					# Hollow core
					if chunk.is_within_bounds(lx, ly, lz):
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

	# ==========================================================================
	# 3. ROOF & DECORATIVE BATTLEMENTS (Parapets at the peak Y level)
	# ==========================================================================
	var roof_y: int = ground_y + TOWER_HEIGHT
	
	for x: int in range(SIZE):
		var lx: int = start_x + x
		for z: int in range(SIZE):
			var lz: int = start_z + z
			
			# Solid roof platform
			if chunk.is_within_bounds(lx, roof_y, lz):
				chunk.set_block(lx, roof_y, lz, BlockType.Type.ICE)
				
			# Battlements on the 4 corners for a medieval castle silhouette
			var is_corner: bool = (x == 0 or x == SIZE - 1) and (z == 0 or z == SIZE - 1)
			if is_corner:
				var battlement_y: int = roof_y + 1
				if chunk.is_within_bounds(lx, battlement_y, lz):
					chunk.set_block(lx, battlement_y, lz, BlockType.Type.ICE)
