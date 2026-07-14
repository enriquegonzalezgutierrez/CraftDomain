# ==============================================================================
# Pathfile: res://src/Domain/World/GlitchRiftVolume.gd
# Description: Pure Domain Entity representing a space-time anomaly (Glitch Rift).
#              Encapsulates the spatial boundaries (AABB) and localized physics 
#              properties (gravity multipliers) of corrupted world sectors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GlitchRiftVolume
extends RefCounted

## Unique identifier for tracking and matching this specific anomaly
var rift_id: String = ""

## The three-dimensional bounding box (AABB) defining the spatial limits of the rift
var bounds: AABB = AABB()

## The localized gravity scale multiplier applied to entities inside this volume.
## Defaults to 0.3 (a 70% reduction in downward kinetic acceleration).
var gravity_scale: float = 0.3


func _init(p_id: String, p_position: Vector3, p_size: Vector3, p_gravity: float = 0.3) -> void:
	rift_id = p_id
	bounds = AABB(p_position, p_size)
	gravity_scale = p_gravity


## Evaluates if a given world coordinate lies within the limits of this anomaly.
func contains_position(global_pos: Vector3) -> bool:
	return bounds.has_point(global_pos)


## Calculates the active gravity acceleration relative to the default system gravity.
func get_localized_gravity(default_gravity: float) -> float:
	return default_gravity * gravity_scale
