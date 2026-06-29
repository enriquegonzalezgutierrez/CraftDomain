# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for simulating agricultural 
#              growth dynamics across all loaded chunks.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating farming tick algorithms.
#              i18n UPGRADE: Uses clean dynamic proxy calls to retrieve active nodes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/AgricultureService.gd
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

## Processes the randomized crop growth updates (Minecraft Random Tick Rate style)
func _execute_random_crop_ticks() -> void:
	if not is_instance_valid(world_controller) or world_state == null:
		return
		
	# Fetch the active renderable chunk nodes list dynamically via clean SRP API
	var active_nodes: Dictionary = world_controller.call("get_active_chunk_nodes")
	if active_nodes.is_empty():
		return
		
	for chunk_pos in active_nodes.keys():
		var chunk_node: ChunkNode = active_nodes[chunk_pos]
		if not is_instance_valid(chunk_node) or chunk_node.chunk == null:
			continue
			
		# Perform exactly 3 random voxel evaluations per active chunk
		for i in range(3):
			var rx := randi() % Chunk.SIZE
			var ry := randi() % Chunk.SIZE
			var rz := randi() % Chunk.SIZE
			
			var current_block: BlockType.Type = chunk_node.chunk.get_block(rx, ry, rz)
			
			# Check and apply biological stage transformations
			if current_block == BlockType.Type.CROP_SEED:
				if randf() < 0.40:
					var global_pos := Vector3i(chunk_pos * Chunk.SIZE) + Vector3i(rx, ry, rz)
					world_controller.call("set_block_globally", global_pos, BlockType.Type.CROP_GROWING)
					print("[AgricultureService] Seed sprouted to YOUNG_SPROUT at global: ", global_pos)
					
			elif current_block == BlockType.Type.CROP_GROWING:
				if randf() < 0.30:
					var global_pos := Vector3i(chunk_pos * Chunk.SIZE) + Vector3i(rx, ry, rz)
					world_controller.call("set_block_globally", global_pos, BlockType.Type.CROP_RIPE)
					print("[AgricultureService] Sprout matured to RIPE_WHEAT at global: ", global_pos)
