# ==============================================================================
# Pathfile: res://src/Domain/World/RoseBushBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a compact, flowering Rose Bush.
# SOLID COMPLIANCE:
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'VoxelGeometricSculptor'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RoseBushBlueprint
extends IStructureBlueprint

const CORE_BLOCK := BlockType.Type.LEAVES
const FLOWER_BLOCK := BlockType.Type.RED_SAND

const MIN_HEIGHT: int = 2
const MAX_HEIGHT: int = 3
const SHRUB_RADIUS: float = 1.2

func get_structure_id() -> int:
	return 12

func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	for y in range(1, height + 1):
		VoxelGeometricSculptor.set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), CORE_BLOCK)
		
	var hub := Vector3i(start_x, ground_y + height, start_z)
	_sculpt_leaf_bush_sphere(chunk, hub, SHRUB_RADIUS, rng)

static func _sculpt_leaf_bush_sphere(chunk: Chunk, hub: Vector3i, radius: float, rng: RandomNumberGenerator) -> void:
	var r_int := int(ceil(radius))
	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			for z in range(-r_int, r_int + 1):
				var dist_sq := float(x * x + y * y + z * z)
				if dist_sq <= radius * radius:
					var target_pos := hub + Vector3i(x, y, z)
					var is_outer_shell := dist_sq > (radius - 0.5) * (radius - 0.5)
					if is_outer_shell and rng.randf() < 0.35:
						VoxelGeometricSculptor.set_block_safe(chunk, target_pos, FLOWER_BLOCK)
					else:
						VoxelGeometricSculptor.set_block_safe(chunk, target_pos, CORE_BLOCK)
