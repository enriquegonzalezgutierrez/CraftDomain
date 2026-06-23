# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for scanning, registering,
#              and dynamically toggling village streetlights during day/night shifts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/StreetlightService.gd
# ==============================================================================
class_name StreetlightService
extends RefCounted

# Dependencies injected on initialization
var world_controller: Node3D
var world_state: WorldState

# Active registered streetlights coordinates: Array[Vector3i]
var _streetlight_coords: Array[Vector3i] = []
var _streetlights_active: bool = false

func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state

## Scans a newly loaded chunk. If it contains a village house, registers its lamppost coordinates.
func register_streetlights_for_chunk(chunk: Chunk) -> void:
	var chunk_pos := chunk.position
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if not has_house:
		return
		
	# The streetlight is placed procedurally inside the cabin chunk at local X=2, Z=10.
	# We search for the STONE block (lantern) placed on top of the WOOD post (height 3)
	var start_x := 2
	var start_z := 10
	var chunk_offset := Vector3i(chunk_pos * Chunk.SIZE)
	
	for y in range(1, Chunk.SIZE):
		var block_type := chunk.get_block(start_x, y, start_z)
		if block_type == BlockType.Type.STONE:
			var below_block := chunk.get_block(start_x, y - 1, start_z)
			if below_block == BlockType.Type.WOOD:
				var global_lantern_pos := chunk_offset + Vector3i(start_x, y, start_z)
				_streetlight_coords.append(global_lantern_pos)
				
				# Ensure correct initial state on load
				if _streetlights_active:
					world_controller.call("set_block_globally", global_lantern_pos, BlockType.Type.GRASS)
				break

## Unregisters streetlights associated with an unloaded chunk pos to prevent memory leaks.
func unregister_streetlights_for_chunk(chunk_pos: Vector3i) -> void:
	var chunk_offset := chunk_pos * Chunk.SIZE
	var filtered_coords: Array[Vector3i] = []
	for coord in _streetlight_coords:
		var relative_pos := coord - chunk_offset
		var is_inside := relative_pos.x >= 0 and relative_pos.x < Chunk.SIZE and relative_pos.z >= 0 and relative_pos.z < Chunk.SIZE
		if not is_inside:
			filtered_coords.append(coord)
	_streetlight_coords = filtered_coords

## Evaluates the daylight state. If shifted, dynamically updates all registered lamppost blocks.
func update_streetlights_state(is_night: bool) -> void:
	if is_night != _streetlights_active:
		_streetlights_active = is_night
		print("[StreetlightService] Day/Night state shifted. Toggling streetlights: ", "ON" if is_night else "OFF")
		
		var lantern_material_type: BlockType.Type = BlockType.Type.GRASS if is_night else BlockType.Type.STONE
		
		for coord in _streetlight_coords:
			world_controller.call("set_block_globally", coord, lantern_material_type)
