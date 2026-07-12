# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/FootstepAudioPlayer.gd
# Description: Infrastructure Component managing spatial 3D footstep audio triggers.
#              Calculates floor block types and manages distance accumulators (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FootstepAudioPlayer
extends Node

var host: CharacterBody3D
var world_controller: Node3D

var _footstep_accumulator: float = 0.0
const STEP_TRIGGER_DISTANCE: float = 2.2


## Injects references to coordinate translations with world grids
func initialize(p_host: CharacterBody3D, p_world_controller: Node3D) -> void:
	host = p_host
	world_controller = p_world_controller


## Processes footstep accumulation during locomotion on floor
func process_footsteps(delta: float, velocity_flat: Vector2) -> void:
	if not is_instance_valid(host):
		return
		
	if host.is_on_floor() and velocity_flat.length_squared() > 0.25:
		_footstep_accumulator += delta * velocity_flat.length()
		if _footstep_accumulator >= STEP_TRIGGER_DISTANCE:
			_footstep_accumulator = 0.0
			_trigger_footstep_sfx()
	else:
		_footstep_accumulator = lerp(_footstep_accumulator, 0.0, delta * 3.0)


func _trigger_footstep_sfx() -> void:
	var block_underneath := Vector3i(
		floori(host.global_position.x),
		floori(host.global_position.y - 0.1),
		floori(host.global_position.z)
	)
	
	var block_below := BlockType.Type.AIR
	if is_instance_valid(world_controller):
		var ws: WorldState = world_controller.get("world_state") as WorldState
		if is_instance_valid(ws):
			block_below = ws.get_block(block_underneath)
			
	var sfx_name := "footstep_stone" # Default solid stone thud
	match block_below:
		BlockType.Type.GRASS, BlockType.Type.DIRT:
			sfx_name = "footstep_grass"
		BlockType.Type.WOOD, BlockType.Type.LEAVES, BlockType.Type.BIRCH_LOG, BlockType.Type.OAK_PLANKS:
			sfx_name = "footstep_wood"
		BlockType.Type.SNOW, BlockType.Type.ICE:
			sfx_name = "footstep_snow"
		BlockType.Type.AIR, BlockType.Type.WATER:
			return # Discard sounds in empty air or swimming
			
	# Trigger spatial 3D sound statically (Service Locator)
	AudioService.play_sfx_static(sfx_name, host.global_position)
