# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic SunLight rotation, and procedural sky color transitions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Audio/CelestialService.gd (Save in Celestial directory)
# ==============================================================================
class_name CelestialService
extends Node

## Speed of time progression (Multiplier: 1.0 is real-time, 60.0 is 24x faster)
var time_speed: float = 40.0

# Dependencies injected by Bootstrap
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

# Internal time tracking (0.0 to 1.0 represents a full 24-hour cycle, starts at 0.25 - Morning)
var _current_time: float = 0.25

# Sky colors for different times of day (Interpolation targets)
const SKY_COLORS = {
	"MORNING_TOP": Color(0.3, 0.45, 0.8),
	"MORNING_HORIZON": Color(0.9, 0.6, 0.4),
	"NOON_TOP": Color(0.2, 0.5, 0.85),
	"NOON_HORIZON": Color(0.55, 0.75, 0.9),
	"SUNSET_TOP": Color(0.15, 0.15, 0.35),
	"SUNSET_HORIZON": Color(0.85, 0.35, 0.2),
	"NIGHT_TOP": Color(0.02, 0.02, 0.05),
	"NIGHT_HORIZON": Color(0.05, 0.05, 0.1)
}

func _ready() -> void:
	name = "CelestialService"

func _process(delta: float) -> void:
	_current_time += (delta * time_speed) / 86400.0 # 86400 seconds in a day
	if _current_time >= 1.0:
		_current_time = 0.0
		
	_update_sun_rotation()
	_update_sky_atmosphere()

func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light):
		return
		
	# Map time [0..1] to a 360-degree rotation angle around X axis
	var angle_rad: float = (_current_time * TAU) - (PI / 2.0)
	
	# Rotate the SunLight node dynamically
	sun_light.rotation.x = angle_rad
	
	# Turn off shadows and reduce light intensity when the sun is below the horizon (night)
	var is_night: bool = _current_time < 0.2 || _current_time > 0.8
	if is_night:
		sun_light.light_energy = 0.0
		sun_light.shadow_enabled = false
	else:
		# Map sunrise/sunset fades smoothly
		var intensity: float = 1.0
		if _current_time < 0.3: # Sunrise fade-in
			intensity = remap(_current_time, 0.2, 0.3, 0.0, 1.0)
		elif _current_time > 0.7: # Sunset fade-out
			intensity = remap(_current_time, 0.7, 0.8, 1.0, 0.0)
		sun_light.light_energy = clamp(intensity, 0.0, 1.0)
		sun_light.shadow_enabled = true

func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment):
		return
		
	var sky: Sky = world_environment.environment.sky
	if sky == null or not (sky.sky_material is ProceduralSkyMaterial):
		return
		
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	
	# Interpolate sky colors based on current time phase
	var top_color: Color
	var horizon_color: Color
	
	if _current_time < 0.25: # Night to Morning transition
		var t := remap(_current_time, 0.0, 0.25, 0.0, 1.0)
		top_color = SKY_COLORS["NIGHT_TOP"].lerp(SKY_COLORS["MORNING_TOP"], t)
		horizon_color = SKY_COLORS["NIGHT_HORIZON"].lerp(SKY_COLORS["MORNING_HORIZON"], t)
	elif _current_time < 0.5: # Morning to Noon transition
		var t := remap(_current_time, 0.25, 0.5, 0.0, 1.0)
		top_color = SKY_COLORS["MORNING_TOP"].lerp(SKY_COLORS["NOON_TOP"], t)
		horizon_color = SKY_COLORS["MORNING_HORIZON"].lerp(SKY_COLORS["NOON_HORIZON"], t)
	elif _current_time < 0.75: # Noon to Sunset transition
		var t := remap(_current_time, 0.5, 0.75, 0.0, 1.0)
		top_color = SKY_COLORS["NOON_TOP"].lerp(SKY_COLORS["SUNSET_TOP"], t)
		horizon_color = SKY_COLORS["NOON_HORIZON"].lerp(SKY_COLORS["SUNSET_HORIZON"], t)
	else: # Sunset to Night transition
		var t := remap(_current_time, 0.75, 1.0, 0.0, 1.0)
		top_color = SKY_COLORS["SUNSET_TOP"].lerp(SKY_COLORS["NIGHT_TOP"], t)
		horizon_color = SKY_COLORS["SUNSET_HORIZON"].lerp(SKY_COLORS["NIGHT_HORIZON"], t)
		
	sky_mat.sky_top_color = top_color
	sky_mat.sky_horizon_color = horizon_color
	sky_mat.ground_horizon_color = horizon_color

## Public helper: Returns true if it is currently nighttime
func is_night_time() -> bool:
	return _current_time < 0.2 or _current_time > 0.8
