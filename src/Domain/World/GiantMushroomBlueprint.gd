# ==============================================================================
# Pathfile: res://src/Domain/World/GiantMushroomBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a massive, red-spotted Mario-style Giant Mushroom.
# SOLID COMPLIANCE:
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'VoxelGeometricSculptor'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GiantMushroomBlueprint
extends IStructureBlueprint

# Red Mushroom Biological Constants
const STALK_BLOCK := BlockType.Type.SNOW # Solid, opaque matte-white stem
const CAP_BLOCK := BlockType.Type.RED_SAND # Vibrant red skin block

const MIN_HEIGHT: int = 4
const MAX_HEIGHT: int = 6
const CAP_RADIUS: float = 2.5


## Concrete Implementation: Returns the unique structure ID for the Giant Mushroom (ID 3)
func get_structure_id() -> int:
	return 3


## Concrete Implementation: Grows a giant spotted red umbrella mushroom
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	# 1. Grow Solid White Stalk
	for y in range(1, height + 1):
		VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), STALK_BLOCK)
		
	# 2. Grow Majestic Spotted Red Cap (Wide flat dome)
	var cap_y := ground_y + height + 1
	var cap_r_int := int(ceil(CAP_RADIUS))
	
	for lx in range(-cap_radius_clamp(cap_r_int), cap_radius_clamp(cap_r_int) + 1):
		for lz in range(-cap_radius_clamp(cap_r_int), cap_radius_clamp(cap_r_int) + 1):
			var dist_sq := lx * lx + lz * lz
			
			if dist_sq <= CAP_RADIUS * CAP_RADIUS:
				var px := start_x + lx
				var pz := start_z + lz
				
				# Base single layer of red skin
				VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(px, cap_y, pz), CAP_BLOCK)
				
				# Symmetrical double layer thickness towards center for dome volume depth
				if dist_sq < (CAP_RADIUS - 0.8) * (CAP_RADIUS - 0.8):
					VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(px, cap_y + 1, pz), CAP_BLOCK)
					
					# SPECIAL: Dot the red cap with white spots (represented by STALK_BLOCK)
					if (lx + lz) % 2 == 0 and (abs(lx) == 1 or abs(lz) == 1):
						VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(px, cap_y + 1, pz), STALK_BLOCK)


## Inline clamping helper ensuring bounds calculations stay safe
func cap_radius_clamp(val: int) -> int:
	return clampi(val, 1, 4)
