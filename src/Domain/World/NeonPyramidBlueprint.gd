# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: NeonPyramidBlueprint
# Description: OCP-compliant structure blueprint that procedurally constructs
#              stepped technological pyramids with glowing cyan/magenta conduit 
#              edges and adaptive foundations. It scans slopes to grow deep 
#              solid stone blocks down to the bedrock, keeping the cyber-shrines 
#              aligned to the ground.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only manages the geometric stepped
#   pyramid math, edge detections, and cyber-illumination.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 7, completely replacing the old static template.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/NeonPyramidBlueprint.gd
# ==============================================================================
class_name NeonPyramidBlueprint
extends IStructureBlueprint

const BASE_RADIUS: int = 2 # Forms a 5x5 base (radius 2)
const HEIGHT: int = 3


## Concrete Contract: Returns the unique structure ID (7) matching the old Neon Pyramid
func get_structure_id() -> int:
	return 7


## Concrete Contract: Builds a cybernetic stepped pyramid anchored to uneven ground
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	
	# ==========================================================================
	# 1. ADAPTIVE METROPOLIS FOUNDATIONS (Paves a solid 5x5 stone baseline)
	# ==========================================================================
	for lx_offset: int in range(-BASE_RADIUS, BASE_RADIUS + 1):
		var lx: int = start_x + lx_offset
		for lz_offset: int in range(-BASE_RADIUS, BASE_RADIUS + 1):
			var lz: int = start_z + lz_offset
			
			# Downward column scan to find solid ground
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz):
					var check_block: BlockType.Type = chunk.get_block(lx, sy, lz)
					if check_block != BlockType.Type.AIR and check_block != BlockType.Type.WATER:
						real_ground_y = sy
						break
			
			# Grow stone support pillars (ID 1)
			for fill_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, fill_y, lz):
					chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)

	# ==========================================================================
	# 2. STEPPED CYBER PLATFORMS (HEIGHT 3, with alternating neon conduit ribs)
	# ==========================================================================
	for y: int in range(HEIGHT):
		var current_radius: int = BASE_RADIUS - y
		var ly: int = ground_y + y + 1
		
		for lx_offset: int in range(-current_radius, current_radius + 1):
			var px: int = start_x + lx_offset
			for lz_offset: int in range(-current_radius, current_radius + 1):
				var pz: int = start_z + lz_offset
				
				if not chunk.is_within_bounds(px, ly, pz):
					continue
					
				# Determine if this coordinate lies on the outer edge/perimeter of the step
				var is_edge: bool = (abs(lx_offset) == current_radius or abs(lz_offset) == current_radius)
				
				if is_edge:
					# Alternating high-contrast emissive neon pathways for edges
					var is_even_conduit: bool = ((lx_offset + lz_offset) % 2 == 0)
					if is_even_conduit:
						chunk.set_block(px, ly, pz, BlockType.Type.NEON_CYAN)
					else:
						chunk.set_block(px, ly, pz, BlockType.Type.NEON_MAGENTA)
				else:
					# Solid dark obsidian/stone core for interior steps
					chunk.set_block(px, ly, pz, BlockType.Type.STONE)

	# ==========================================================================
	# 3. GLOWING APEX PINNACLE (Peak Y level)
	# ==========================================================================
	var top_y: int = ground_y + HEIGHT + 1
	if chunk.is_within_bounds(start_x, top_y, start_z):
		# Places a brilliant cherry blossom conduit (ID 13) at the tip of the shrine
		chunk.set_block(start_x, top_y, start_z, BlockType.Type.NEON_MAGENTA)
