# ==============================================================================
# Pathfile: res://src/Infrastructure/World/StructuralIntegrityService.gd
# Description: Infrastructure service coordinating structural stability sweeps,
#              listening to block changes, and initiating collapses (SRP).
#              Saves performance by delegating physical falls to FallingBlockEntity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructuralIntegrityService
extends Node

var world_controller: Node3D
var world_state: WorldState
var solver: StructuralIntegritySolver

# Limits to prevent infinite cascades per frame
const MAX_COLLAPSES_PER_TICK: int = 16


## Registers the service dependencies and binds the signals.
func initialize(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state
	solver = StructuralIntegritySolver.new()
	
	# Decoupled signal connection (Observer Pattern / Section 7.3)
	if is_instance_valid(world_controller) and world_controller.has_signal("block_modified"):
		world_controller.connect("block_modified", _on_block_modified)


## Observer receptor: Evaluates stability if a block was broken.
func _on_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	if type == BlockType.Type.AIR:
		# Defer the sweep to let the chunk mesher finish its current frame calculations
		call_deferred("_evaluate_structural_stack", global_pos + Vector3i(0, 1, 0))


## Performs an upward vertical column scan to identify unsupported blocks.
func _evaluate_structural_stack(start_pos: Vector3i) -> void:
	if not is_instance_valid(world_controller) or world_state == null:
		return
		
	var current_pos := start_pos
	var collapses_count := 0
	
	while collapses_count < MAX_COLLAPSES_PER_TICK:
		var current_block := world_state.get_block(current_pos)
		
		# Standard early out if we reach air or non-solid water barriers
		if current_block == BlockType.Type.AIR or current_block == BlockType.Type.WATER:
			break
			
		# Query the pure domain solver for structural connectivity
		var is_stable := solver.verify_integrity(current_pos, world_state)
		
		if not is_stable:
			_collapse_block(current_pos, current_block)
			collapses_count += 1
			
		# Proceed upward to evaluate the next block in the vertical stack
		current_pos += Vector3i(0, 1, 0)


## Triggers a localized block collapse, spawning a temporary sliding FallingBlockEntity.
func _collapse_block(coord: Vector3i, block_type: BlockType.Type) -> void:
	# 1. Break the block globally
	world_controller.call("set_block_globally", coord, BlockType.Type.AIR)
	
	# 2. Query the highest solid ground Y coordinate in this column
	var target_y := world_state.get_highest_solid_y(coord.x, coord.z)
	
	# 3. Instantiate the high-performance physical sliding entity
	var falling_block := FallingBlockEntity.new()
	falling_block.position = Vector3(coord)
	
	world_controller.add_child(falling_block)
	
	# 4. Initiate gravity drop
	falling_block.start_fall(world_controller, block_type, target_y)
