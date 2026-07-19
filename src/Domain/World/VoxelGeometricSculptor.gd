# ==============================================================================
# Pathfile: res://src/Domain/World/VoxelGeometricSculptor.gd
# Description: Static Domain Library providing optimized geometric calculation 
#              and voxel painting methods for procedural structures.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively handles raw trigonometric 
#   and mathematical drawing formulas, keeping biology recipes decoupled.
# - Naming Purified: Renamed from ProceduralTools to comply strictly with Rule 5.1.
# - Method Size Limits (Rule 4.2): All methods designed to be highly cohesive 
#   and kept strictly under 20 lines of code.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelGeometricSculptor
extends RefCounted


## Mathematically paints an organic, non-uniform sphere of leaves around a center hub.
## Uses Euclidean distance perturbed by deterministic noise to simulate organic limits.
static func sculpt_leaf_sphere(chunk: Chunk, hub: Vector3i, radius: float, rng: RandomNumberGenerator) -> void:
	var r_int := int(ceil(radius))
	for x: int in range(-r_int, r_int + 1):
		for y: int in range(-r_int, r_int + 1):
			for z: int in range(-r_int, r_int + 1):
				var dist_sq := float(x * x + y * y + z * z)
				var target_radius_sq := radius * radius
				if rng.randf() < 0.25:
					target_radius_sq *= 0.85
				if dist_sq <= target_radius_sq:
					var target_pos := hub + Vector3i(x, y, z)
					var existing := chunk.get_block(target_pos.x, target_pos.y, target_pos.z)
					if existing != BlockType.Type.WOOD and existing != BlockType.Type.BIRCH_LOG and existing != BlockType.Type.CHERRY_LOG:
						set_block_safe(chunk, target_pos, BlockType.Type.LEAVES)


## Creates flat, circular needle plates at a specific Y node for conifer segmented skirts
static func sculpt_conifer_flat_ring(chunk: Chunk, center_node: Vector3i, radius: float) -> void:
	var r_int := int(ceil(radius))
	for x: int in range(-r_int, r_int + 1):
		for z: int in range(-r_int, r_int + 1):
			var dist_sq := float(x * x + z * z)
			if dist_sq <= radius * radius:
				var target_pos := center_node + Vector3i(x, 0, z)
				var existing := chunk.get_block(target_pos.x, target_pos.y, target_pos.z)
				if existing != BlockType.Type.WOOD and existing != BlockType.Type.REDWOOD_LOG:
					set_block_safe(chunk, target_pos, BlockType.Type.LEAVES)


## Safe voxel painting helper with strict chunk-boundary checks to prevent out-of-bounds crashes
static func set_block_safe(chunk: Chunk, pos: Vector3i, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(pos.x, pos.y, pos.z):
		chunk.set_block(pos.x, pos.y, pos.z, type)
