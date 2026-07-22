# ==============================================================================
# Pathfile: res://src/Infrastructure/World/VegetationProp.gd
# Description: Infrastructure Component attached to 3D vegetation props.
#              Simulates organic, high-performance 3D wind sways using 
#              CPU time ticks without editor-only RenderingServer queries.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly 3D prop sways.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VegetationProp
extends Node3D

var _phase_offset: float = 0.0


func _ready() -> void:
	name = "VegetationProp"
	_calculate_spatial_phase_offset()


func _calculate_spatial_phase_offset() -> void:
	# Phase offset perturbed by global world coordinates so nearby plants don't sway identically
	_phase_offset = (global_position.x * 0.72) + (global_position.z * 1.15)


func _process(_delta: float) -> void:
	_apply_procedural_wind_sway()


func _apply_procedural_wind_sway() -> void:
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	var wave_time := (time_sec * 2.2) + _phase_offset
	
	# Smooth 3D trigonometric sways on horizontal XZ plane
	var sway_x := sin(wave_time) * 0.04
	var sway_z := cos(wave_time * 0.85) * 0.03
	
	rotation.z = sway_x
	rotation.x = sway_z
