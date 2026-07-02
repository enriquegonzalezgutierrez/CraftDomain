# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for scanning, registering,
#              and dynamically toggling village streetlights during day/night shifts.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates light and 
#                night twilight transition logic, delegating block geometry placement 
#                entirely to the dedicated StreetlightBlueprint.
#              CREATIVE OVERHAUL (DYNAMIC ENTITY DOCKING):
#              - Stripped away the old chunk voxel scanner entirely. The service 
#                now connects reactively to `child_entered_tree` of the WorldController.
#                Whenever a physical 3D StreetlightEntity spawns (organically or 
#                in villages), the service automatically synchronizes its light state 
#                to match the active day/night cycle.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/StreetlightService.gd
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
	
	# Connect to WorldController's children changes to auto-initialize newly spawned lamps!
	if is_instance_valid(world_controller):
		world_controller.child_entered_tree.connect(_on_child_entered_tree)


## Event Callback: Automatically synchronizes the light status of any 3D lamppost 
## the moment it is loaded or spawned procedural in the world.
func _on_child_entered_tree(node: Node) -> void:
	if node is StreetlightEntity:
		node.set_lights_active(_streetlights_active)


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
		
		# Zero-rebuild iteration: Direct, ultra-fast loop updating light states on entities
		if is_instance_valid(world_controller):
			for child: Node in world_controller.get_children():
				if child is StreetlightEntity:
					child.set_lights_active(is_night)
