# ==============================================================================
# Pathfile: res://src/Domain/World/DeadShrubBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a dry, leafless, twisted Dead Shrub.
# SOLID COMPLIANCE:
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'VoxelGeometricSculptor'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DeadShrubBlueprint
extends IStructureBlueprint

const TIMBER_BLOCK := BlockType.Type.WOOD
const MIN_HEIGHT: int = 1
const MAX_HEIGHT: int = 2
const LEAN_FACTOR: float = 0.50

func get_structure_id() -> int:
	return 14

func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	
	for y in range(1, height + 1):
		current_pos.y += 1.0
		if rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		VoxelGeometricSculptor.set_block_safe(chunk, node, TIMBER_BLOCK)
		
	var branch_pos := Vector3i(start_x, ground_y + height, start_z)
	
	if rng.randf() < 0.65:
		var side_pos_a := branch_pos + Vector3i(1, 0, 0)
		_set_shrub_branch(chunk, side_pos_a)
		
	if rng.randf() < 0.65:
		var side_pos_b := branch_pos + Vector3i(-1, 1, -1)
		_set_shrub_branch(chunk, side_pos_b)

func _set_shrub_branch(chunk: Chunk, pos: Vector3i) -> void:
	var existing := chunk.get_block(pos.x, pos.y, pos.z)
	if existing == BlockType.Type.AIR:
		VoxelGeometricSculptor.set_block_safe(chunk, pos, TIMBER_BLOCK)
