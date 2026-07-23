# ==============================================================================
# Pathfile: res://src/Infrastructure/World/StreetlightService.gd
# Description: Infrastructure Service managing village streetlights, active 
#              lighting states, and day/night twilight transitions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StreetlightService
extends RefCounted

# Dependencies injected on initialization
var world_controller: Node3D
var world_state: WorldState

# State
var _streetlights_active: bool = false


func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state


## API Stub (Maintained for backwards compilation safety with WorldController)
func register_streetlights_for_chunk(_chunk: Chunk) -> void:
	pass


## API Stub (Maintained for backwards compilation safety with WorldController)
func unregister_streetlights_for_chunk(_chunk_pos: Vector3i) -> void:
	pass


## Evaluates the daylight state and updates all spawned 3D streetlight entities instantly
func update_streetlights_state(is_night: bool) -> void:
	if is_night != _streetlights_active:
		_streetlights_active = is_night
		print("[StreetlightService] Twilight shift. Toggling 3D Streetlights: ", "ON" if is_night else "OFF")
		
		if is_instance_valid(world_controller):
			for child: Node in world_controller.get_children():
				if child is StreetlightEntity:
					child.set_lights_active(is_night)
