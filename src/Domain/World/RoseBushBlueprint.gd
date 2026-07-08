# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a compact, flowering Rose Bush.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the height ratios,
#   foliage density, and flower placements specific to the Rose Bush species.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Bush-specific 
#   growth parameters are closed to modifications from other species.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'ProceduralTools'.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RoseBushBlueprint.gd
# ==============================================================================
class_name RoseBushBlueprint
extends IStructureBlueprint

# Rose Bush Biological Constants
const CORE_BLOCK := BlockType.Type.LEAVES # Dense green shrub core
const FLOWER_BLOCK := BlockType.Type.RED_SAND # Red rose blossom block

const MIN_HEIGHT: int = 2
const MAX_HEIGHT: int = 3
const SHRUB_RADIUS: float = 1.2


## Concrete Implementation: Returns the unique structure ID for the Rose Bush (ID 12)
func get_structure_id() -> int:
	return 12


## Concrete Implementation: Grows a compact flowering rose bush
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Seed RNG deterministically based on coordinates to guarantee reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine short height for this compact shrub
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	# 1. Grow Dense Green Core Stalk
	for y in range(1, height + 1):
		ProceduralTools.set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), CORE_BLOCK)
		
	# 2. Sculpt Compact Foliage Sphere around the shrub tip
	var hub := Vector3i(start_x, ground_y + height, start_z)
	_sculpt_leaf_bush_sphere(chunk, hub, SHRUB_RADIUS, rng)


## Private Helper: Paints a compact dome of leaves interspersed with blooming red roses
static func _sculpt_leaf_bush_sphere(chunk: Chunk, hub: Vector3i, radius: float, rng: RandomNumberGenerator) -> void:
	var r_int := int(ceil(radius))
	
	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			for z in range(-r_int, r_int + 1):
				var dist_sq := float(x * x + y * y + z * z)
				
				if dist_sq <= radius * radius:
					var target_pos := hub + Vector3i(x, y, z)
					
					# 30% chance to place a blooming red rose on the outer edge, otherwise place green leaves
					var is_outer_shell := dist_sq > (radius - 0.5) * (radius - 0.5)
					if is_outer_shell and rng.randf() < 0.35:
						ProceduralTools.set_block_safe(chunk, target_pos, FLOWER_BLOCK)
					else:
						ProceduralTools.set_block_safe(chunk, target_pos, CORE_BLOCK)
