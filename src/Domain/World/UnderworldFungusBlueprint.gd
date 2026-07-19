# ==============================================================================
# Pathfile: res://src/Domain/World/UnderworldFungusBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a glowing, neon-cyan Giant Underworld Fungus.
# SOLID COMPLIANCE:
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'VoxelGeometricSculptor'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	# 1. Grow Basaltic Stalk
	for y in range(1, height + 1):
		VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), STALK_BLOCK)
		
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
				VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(px, cap_y, pz), GILLS_BLOCK)
				
	# 3. Add Emissive Pinnacle Bulb at the absolute top center
	var pinnacle_y := cap_y + 1
	VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(start_x, pinnacle_y, start_z), GILLS_BLOCK)


## Inline clamping helper ensuring bounds calculations stay safe
func cap_radius_clamp(val: int) -> int:
	return clampi(val, 1, 3)
