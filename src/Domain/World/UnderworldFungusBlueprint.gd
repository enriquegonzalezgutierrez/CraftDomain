# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a glowing, neon-cyan Giant Underworld Fungus.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the height ratios,
#   cap diameter, and emissive neon gill placements specific to the Blue Fungus.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Fungus-specific 
#   growth parameters are closed to modifications from other species.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'ProceduralTools'.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/UnderworldFungusBlueprint.gd
# ==============================================================================
class_name UnderworldFungusBlueprint
extends IStructureBlueprint

# Underworld Fungus Biological Constants
const STALK_BLOCK := BlockType.Type.STONE # Rusted basaltic dark-stone stem
const GILLS_BLOCK := BlockType.Type.NEON_CYAN # Radiant cyber-conduit gills block

const MIN_HEIGHT: int = 3
const MAX_HEIGHT: int = 5
const CAP_RADIUS: float = 2.0


## Concrete Implementation: Returns the unique structure ID for the Underworld Fungus (ID 11)
func get_structure_id() -> int:
	return 11


## Concrete Implementation: Grows a giant glowing blue underworld fungus
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Seed RNG deterministically based on coordinates to guarantee reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine height for this deep instance
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	# 1. Grow Basaltic Stalk
	for y in range(1, height + 1):
		ProceduralTools.set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), STALK_BLOCK)
		
	# 2. Grow Glowing Cyan Fungal Cap (Circle gills)
	var cap_y := ground_y + height + 1
	var cap_r_int := int(ceil(CAP_RADIUS))
	
	for lx in range(-cap_radius_clamp(cap_r_int), cap_radius_clamp(cap_r_int) + 1):
		for lz in range(-cap_radius_clamp(cap_r_int), cap_radius_clamp(cap_r_int) + 1):
			var dist_sq := lx * lx + lz * lz
			
			if dist_sq <= CAP_RADIUS * CAP_RADIUS:
				var px := start_x + lx
				var pz := start_z + lz
				
				# Base glowing gills plate
				ProceduralTools.set_block_safe(chunk, Vector3i(px, cap_y, pz), GILLS_BLOCK)
				
	# 3. Add Emissive Pinnacle Bulb at the absolute top center for dramatic cave lighting
	var pinnacle_y := cap_y + 1
	ProceduralTools.set_block_safe(chunk, Vector3i(start_x, pinnacle_y, start_z), GILLS_BLOCK)


## Inline clamping helper ensuring bounds calculations stay safe
func cap_radius_clamp(val: int) -> int:
	return clampi(val, 1, 3)
