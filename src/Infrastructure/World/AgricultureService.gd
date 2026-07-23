# ==============================================================================
# Pathfile: res://src/Infrastructure/World/AgricultureService.gd
# Description: Infrastructure Service simulating agricultural growth dynamics 
#              and stage transformations across active loaded chunks.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AgricultureService
extends RefCounted

# Climatological tick timer parameters (Ticking every 12 seconds)
const TICK_INTERVAL: float = 12.0
var _tick_timer: float = TICK_INTERVAL

# Dependencies injected on startup
var world_controller: Node3D
var world_state: WorldState


func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state


## Public tick coordinator called from the WorldController main loop
func process_agriculture_ticks(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		_execute_random_crop_ticks()


## Processes the randomized crop growth updates
func _execute_random_crop_ticks() -> void:
	if not is_instance_valid(world_controller) or world_state == null:
		return
		
	var active_nodes: Dictionary = world_controller.call("get_active_chunk_nodes") as Dictionary
	if active_nodes.is_empty():
		return
		
	for chunk_pos: Vector3i in active_nodes.keys():
		_evaluate_chunk_crop_ticks(chunk_pos)


func _evaluate_chunk_crop_ticks(chunk_pos: Vector3i) -> void:
	var chunk: Chunk = world_state.get_chunk(chunk_pos)
	if chunk == null:
		return
		
	for i: int in range(3):
		var rx := randi() % Chunk.SIZE
		var ry := randi() % Chunk.SIZE
		var rz := randi() % Chunk.SIZE
		_process_single_crop_voxel(chunk, chunk_pos, Vector3i(rx, ry, rz))


func _process_single_crop_voxel(chunk: Chunk, chunk_pos: Vector3i, local_pos: Vector3i) -> void:
	var current_block: BlockType.Type = chunk.get_block(local_pos.x, local_pos.y, local_pos.z)
	var global_pos := Vector3i(chunk_pos * Chunk.SIZE) + local_pos
	
	if current_block == BlockType.Type.CROP_SEED and randf() < 0.40:
		world_controller.call("set_block_globally", global_pos, BlockType.Type.CROP_GROWING)
	elif current_block == BlockType.Type.CROP_GROWING and randf() < 0.30:
		world_controller.call("set_block_globally", global_pos, BlockType.Type.CROP_RIPE)
