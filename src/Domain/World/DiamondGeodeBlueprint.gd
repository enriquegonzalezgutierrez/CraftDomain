# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Description: Concrete Ore Vein Strategy implementing a spherical shell algorithm 
#              to generate beautiful, hollow-style Diamond Geodes with Glowstone cores.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric sphere evaluations and core-shell material bounds.
#              - Liskov Substitution Principle (LSP): Fully satisfies the 
#                IOreVeinBlueprint contract signatures without modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/DiamondGeodeBlueprint.gd
# ==============================================================================
class_name DiamondGeodeBlueprint
extends IOreVeinBlueprint

const ORE_TYPE := BlockType.Type.DIAMOND_ORE
const CORE_TYPE := BlockType.Type.GLOWSTONE
const REPLACEABLE_TYPE := BlockType.Type.STONE

# Geode radius constraints
const MIN_RADIUS: float = 1.6
const MAX_RADIUS: float = 2.4


## Concrete Implementation: Returns the unique identifier for the Diamond Geode (ID 2)
func get_vein_id() -> int:
	return 2


## Concrete Implementation: Returns the diamond ore block type
func get_ore_block_type() -> BlockType.Type:
	return ORE_TYPE


## Concrete Implementation: Generates a small spherical crystal geode cluster replacing chiseled stone blocks
func grow_vein(chunk: Chunk, start_x: int, start_y: int, start_z: int, seed_hash: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash

	# Determine randomized radius for this cluster
	var radius := rng.randf_range(MIN_RADIUS, MAX_RADIUS)
	var r_int := int(ceil(radius))

	# 1. 3D Nested loops to evaluate bounding cube steps
	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			for z in range(-r_int, r_int + 1):
				var px := start_x + x
				var py := start_y + y
				var pz := start_z + z

				# Bounds safety check
				if not chunk.is_within_bounds(px, py, pz):
					continue

				# Calculate the precise Euclidean distance squared
				var dist_sq := float(x*x + y*y + z*z)
				var radius_sq := radius * radius

				if dist_sq <= radius_sq:
					# Verify that we are only replacing solid stone matrix blocks
					var current_block := chunk.get_block(px, py, pz)
					if current_block == REPLACEABLE_TYPE:
						# Threshold check:
						# Outside shell (dist_sq > (radius-0.75)^2) becomes Diamond Ore
						var shell_inner_limit := (radius - 0.75) * (radius - 0.75)
						
						if dist_sq > shell_inner_limit:
							chunk.set_block(px, py, pz, ORE_TYPE)
						else:
							# Inner core becomes luminous Glowstone crystals
							chunk.set_block(px, py, pz, CORE_TYPE)
