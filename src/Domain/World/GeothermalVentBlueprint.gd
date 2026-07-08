# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Description: Concrete Structure Blueprint implementing a procedural Geothermal 
#              Lava Vent. Generates a circular basalt-ring crater with a deep 
#              subterranean volcanic tube filled with active Lava.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric circle carving and volcanic block-offset rules.
#              - Liskov Substitution Principle (LSP): Fully satisfies the 
#                IStructureBlueprint interface contract.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/GeothermalVentBlueprint.gd
# ==============================================================================
class_name GeothermalVentBlueprint
extends IStructureBlueprint

const BLOCK_RIM := BlockType.Type.STONE
const BLOCK_ACCENT := BlockType.Type.COAL_ORE
const BLOCK_FLUID := BlockType.Type.LAVA

const CRATER_RADIUS: float = 2.4


## Concrete Implementation: Returns the unique structure ID for the Geothermal Vent (ID 16)
func get_structure_id() -> int:
	return 16


## Concrete Implementation: Sculpts the circular volcanic crater and carves a deep subterranean lava shaft
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Seed local RNG based on coordinates for deterministic variety
	var coord_hash: int = abs(start_x * 73856093 ^ start_z * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = coord_hash

	var r_int: int = int(ceil(CRATER_RADIUS))

	# 2. Carve and Build Crater Dome (Evaluating a 5x5 area)
	for x: int in range(-r_int, r_int + 1):
		for z: int in range(-r_int, r_int + 1):
			var lx: int = start_x + x
			var lz: int = start_z + z

			if not chunk.is_within_bounds(lx, ground_y, lz):
				continue

			var dist_sq: float = float(x*x + z*z)
			var radius_sq: float = CRATER_RADIUS * CRATER_RADIUS

			if dist_sq <= radius_sq:
				# A. Crater Core: Core coordinates (distance squared < 1.5) represent the liquid mouth
				if dist_sq < 1.5:
					# Volcanic Core: Carve deep tube (down to Y-4) and fill with high-volatility Lava
					for cy: int in range(ground_y + 1, ground_y - 4, -1):
						_set_block_safe(chunk, lx, cy, lz, BLOCK_FLUID)
				else:
					# B. Crater Border Rim: Raised chiseled basalt rim to pool the magma
					# Raise border Y height by +1 to contain the central lava pool
					_set_block_safe(chunk, lx, ground_y, lz, BLOCK_RIM)
					
					var border_type := BLOCK_RIM if rng.randf() < 0.70 else BLOCK_ACCENT
					_set_block_safe(chunk, lx, ground_y + 1, lz, border_type)
					
					# Smooth transition stepping down on the outer shell
					if dist_sq > (CRATER_RADIUS - 0.7) * (CRATER_RADIUS - 0.7):
						_set_block_safe(chunk, lx, ground_y + 2, lz, BlockType.Type.AIR)


## Internal Helper: Safely sets block verifying chunk boundaries
func _set_block_safe(chunk: Chunk, x: int, y: int, z: int, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(x, y, z):
		chunk.set_block(x, y, z, type)
