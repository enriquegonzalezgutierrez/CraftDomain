# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: DynamicHarborPierBlueprint
# Description: OCP-compliant structure blueprint that procedurally builds an
#              adaptive harbor pier extending into the ocean. Instead of using 
#              static sizes, it projects outward and scans downward to calculate
#              sea-floor depths, constructing solid stone columns to support the
#              wooden deck walkways and placing guiding Glowstone lamps at the tip.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the coastline
#   projection, sea-floor depth calculations, and wooden pier assembly.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 9, completely replacing the old static JSON template without
#   modifying generation loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/DynamicHarborPierBlueprint.gd
# ==============================================================================
class_name DynamicHarborPierBlueprint
extends IStructureBlueprint

const PIER_LENGTH: int = 6
const PIER_WIDTH: int = 2


## Concrete Contract: Returns the unique structure ID (9) matching the old Harbor Pier
func get_structure_id() -> int:
	return 9


## Concrete Contract: Projects and adapts a wooden pier over ocean water
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Walkway level is set exactly to Y = beach_level + 1 to float above sand
	var deck_y: int = ground_y + 1
	
	# ==========================================================================
	# 1. PIER BODY PROJECTION (Z-Axis extension)
	# ==========================================================================
	for dz: int in range(PIER_LENGTH):
		var lz: int = start_z + dz
		
		for dx: int in range(PIER_WIDTH):
			var lx: int = start_x + dx
			
			if not chunk.is_within_bounds(lx, deck_y, lz):
				continue
				
			# A. Scan downwards to find the sea-floor (skipping Air and Water)
			var sea_floor_y: int = ground_y - 2
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz):
					var check_block: BlockType.Type = chunk.get_block(lx, sy, lz)
					if check_block != BlockType.Type.AIR and check_block != BlockType.Type.WATER:
						sea_floor_y = sy
						break
						
			# B. Build solid structural stone foundation column up to deck level
			for col_y: int in range(sea_floor_y, deck_y):
				if chunk.is_within_bounds(lx, col_y, lz):
					chunk.set_block(lx, col_y, lz, BlockType.Type.STONE)
					
			# C. Lay down refined wooden deck walkways
			chunk.set_block(lx, deck_y, lz, BlockType.Type.WOOD)

	# ==========================================================================
	# 2. EMBELLISHMENT: PORT GUIDING SEALIGHTS (Placed at the tip of the pier)
	# ==========================================================================
	var end_z: int = start_z + PIER_LENGTH - 1
	
	for dx: int in range(PIER_WIDTH):
		var lx: int = start_x + dx
		var post_y: int = deck_y + 1
		var lamp_y: int = deck_y + 2
		
		# Place vertical wooden guiding posts
		if chunk.is_within_bounds(lx, post_y, end_z):
			chunk.set_block(lx, post_y, end_z, BlockType.Type.WOOD)
			
		# Mount glowing amber guide lamps (Glowstone) on top
		if chunk.is_within_bounds(lx, lamp_y, end_z):
			chunk.set_block(lx, lamp_y, end_z, BlockType.Type.GLOWSTONE)
