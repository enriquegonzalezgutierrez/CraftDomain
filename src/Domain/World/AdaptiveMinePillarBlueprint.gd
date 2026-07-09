# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: AdaptiveMinePillarBlueprint
# Description: OCP-compliant structure blueprint that procedurally grows mine
#              support pillars inside caverns. Instead of using static heights,
#              it scans upwards to detect the actual stone cave ceiling, scaling
#              the support post and adding horizontal support trusses and a 
#              hanging Glowstone lantern dynamically.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only manages the geometric scanning
#   and mathematical assembly of cave support pillars.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 5, completely replacing the old static JSON template without
#   modifying generation loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/AdaptiveMinePillarBlueprint.gd
# ==============================================================================
class_name AdaptiveMinePillarBlueprint
extends IStructureBlueprint


## Concrete Contract: Returns the unique structure ID (5) matching the old Mine Pillar
func get_structure_id() -> int:
	return 5


## Concrete Contract: Scans, scales, and builds an adaptive mine support truss
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var ceiling_y: int = -1
	
	# ==========================================================================
	# 1. CAVERN HEIGHT VERTICAL SCAN (Up to 12 blocks limit)
	# ==========================================================================
	for y: int in range(ground_y + 2, ground_y + 13):
		if chunk.is_within_bounds(start_x, y, start_z):
			var block: BlockType.Type = chunk.get_block(start_x, y, start_z)
			if BlockType.is_solid(block):
				ceiling_y = y
				break

	# ==========================================================================
	# 2. ADAPTIVE GEOMETRY ASSEMBLER
	# ==========================================================================
	if ceiling_y != -1 and (ceiling_y - ground_y) >= 3:
		# A. Build dynamic support post from floor to ceiling
		for py: int in range(ground_y + 1, ceiling_y):
			chunk.set_block(start_x, py, start_z, BlockType.Type.WOOD)
		
		# B. Build horizontal structural bracing along the X-axis (bracing ceiling)
		var brace_y: int = ceiling_y - 1
		for dx: int in [-1, 1]:
			var bx: int = start_x + dx
			if chunk.is_within_bounds(bx, brace_y, start_z):
				chunk.set_block(bx, brace_y, start_z, BlockType.Type.WOOD)
				
		# C. Hang a cozy Glowstone lantern under the right bracing node
		var lantern_x: int = start_x + 1
		var lantern_y: int = brace_y - 1
		if chunk.is_within_bounds(lantern_x, lantern_y, start_z):
			chunk.set_block(lantern_x, lantern_y, start_z, BlockType.Type.GLOWSTONE)
			
	else:
		# ==========================================================================
		# 3. ROBUST FALLBACK (If ceiling is missing or cavern is too tall)
		# Builds a default 4-block high pilar capped with a Glowstone lamp
		# ==========================================================================
		for py: int in range(1, 4):
			var ly: int = ground_y + py
			if chunk.is_within_bounds(start_x, ly, start_z):
				chunk.set_block(start_x, ly, start_z, BlockType.Type.WOOD)
				
		var top_y: int = ground_y + 4
		if chunk.is_within_bounds(start_x, top_y, start_z):
			chunk.set_block(start_x, top_y, start_z, BlockType.Type.GLOWSTONE)
