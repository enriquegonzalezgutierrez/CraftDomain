# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic SunLight and MoonLight rotation, and procedural sky transitions.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only manages physical orbits
#                and day timelines, delegating weather-uniform parameters to the GPU.
#              FIXED: Detects the active weather state from WeatherService dynamically
#              and smoothly interpolates `_current_storm_weight` using a linear 
#              interpolation (lerp) over time. Updates the custom GPU Sky Shader
#              with the dynamic `storm_weight` parameter to render realistic 
#              cloud coverage during rain/snow.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Celestial/CelestialService.gd
# ==============================================================================
class_name CelestialService
extends Node

## Speed of time progression (96.0 multiplier makes a full day last exactly 15 minutes)
var time_speed: float = 96.0

# Dependencies injected by Bootstrap
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

# Dynamic Moon Light created at runtime (SRP compliant)
var moon_light: DirectionalLight3D

# Internal time tracking (starts at 0.5 - High Noon)
var _current_time: float = 0.5
var _last_time_value: float = 0.5

# Calendar days tracking for lunar cycle simulation
var _calendar_days: int = 14 # Start at day 14 (Full Moon) for immediate visual feedback!

# Weather-Storm parameters
var _current_storm_weight: float = 0.0

func _ready() -> void:
	name = "CelestialService"
	_setup_dynamic_moon_light()

func _process(delta: float) -> void:
	# Update daily cycle
	_last_time_value = _current_time
	_current_time += (delta * time_speed) / 86400.0
	
	if _current_time >= 1.0:
		_current_time = 0.0
		
	# Increment calendar days on midnight crossing to cycle moon phases
	if _last_time_value > 0.95 and _current_time < 0.05:
		_calendar_days += 1
		if _calendar_days > 28:
			_calendar_days = 1
		print("[CelestialService] Day Crossed! Calendar Day: ", _calendar_days, " | Moon Phase: ", get_moon_phase_name())
		
	_update_sun_rotation()
	_update_moon_rotation()
	
	# Smoothly calculate weather cloud overcast transition (approx. 5 seconds transition)
	_process_weather_transitions(delta)
	
	_update_sky_atmosphere()

## Programmatically instantiates the secondary silver-blue Moon light source
func _setup_dynamic_moon_light() -> void:
	print("[CelestialService] Creating dynamic MoonLight source...")
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.0
	
	# Cold, pale silver-blue moonlight tint
	moon_light.light_color = Color(0.75, 0.85, 1.0)
	moon_light.light_energy = 0.0 # Silent start
	moon_light.light_indirect_energy = 1.0
	
	# Configured to LIGHT_AND_SKY so the sky shader receives the Moon's rotation vectors
	moon_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	
	add_child(moon_light)

func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light):
		return
		
	# Inverted angle calculation to ensure the light shines DOWNWARDS during daytime
	var angle_rad: float = -((_current_time * TAU) - (PI / 2.0))
	sun_light.rotation.x = angle_rad
	sun_light.rotation.y = deg_to_rad(35)
	
	# Fade sun in/out based on daylight limits
	var is_night: bool = _current_time < 0.2 || _current_time > 0.8
	if is_night:
		sun_light.light_energy = 0.0
		sun_light.shadow_enabled = false
	else:
		var intensity: float = 1.2
		if _current_time < 0.3: # Sunrise fade
			intensity = remap(_current_time, 0.2, 0.3, 0.0, 1.2)
		elif _current_time > 0.7: # Sunset fade
			intensity = remap(_current_time, 0.7, 0.8, 1.2, 0.0)
		sun_light.light_energy = clamp(intensity, 0.0, 1.2)
		sun_light.shadow_enabled = true

## Rotates the Moon opposite to the Sun and updates its energy based on the phase
func _update_moon_rotation() -> void:
	if not is_instance_valid(moon_light):
		return
		
	# Moon rotates 180 degrees (PI radians) out-of-phase with the Sun
	var angle_rad: float = -((_current_time * TAU) - (PI / 2.0)) + PI
	moon_light.rotation.x = angle_rad
	moon_light.rotation.y = deg_to_rad(-145) # Azimuth opposite angle
	
	# Verify if it is currently nighttime
	var is_night: bool = _current_time < 0.22 or _current_time > 0.78
	if not is_night:
		moon_light.light_energy = 0.0
		moon_light.shadow_enabled = false
	else:
		var moon_phase_mult: float = 1.0 - abs((float(_calendar_days) - 14.0) / 14.0)
		
		# Fade moon energy smoothly during transitions (Sunset/Sunrise)
		var max_intensity: float = 0.45 * moon_phase_mult
		var intensity: float = max_intensity
		
		if _current_time > 0.78 and _current_time < 0.88: # Sunset rise
			intensity = remap(_current_time, 0.78, 0.88, 0.0, max_intensity)
		elif _current_time < 0.22 and _current_time > 0.12: # Sunrise set
			intensity = remap(_current_time, 0.12, 0.22, max_intensity, 0.0)
			
		moon_light.light_energy = clamp(intensity, 0.0, 0.45)
		moon_light.shadow_enabled = moon_light.light_energy > 0.05

## Queries the Weather Service sibling and interpolates storm overcast weights
func _process_weather_transitions(delta: float) -> void:
	var weather_node: Node = get_parent().get_node_or_null("WeatherService")
	var target_storm: float = 0.0
	
	if is_instance_valid(weather_node):
		var w_type: int = int(weather_node.get("current_weather"))
		# WeatherType.SUNNY is 0. If current_weather > 0 (RAINY=1, SNOWY=2), we close the clouds
		if w_type != 0:
			target_storm = 1.0
			
	# Smoothly transition storm overcast weight (lerping toward target)
	_current_storm_weight = lerp(_current_storm_weight, target_storm, delta * 0.4)

## Deterministic Sky Synchronization using explicit static typing
func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment):
		return
		
	var sky: Sky = world_environment.environment.sky
	if sky == null or not (sky.sky_material is ShaderMaterial):
		return
		
	var sky_mat: ShaderMaterial = sky.sky_material as ShaderMaterial
	
	# 1. Synchronize the Sun's position and the clock's day weight
	if is_instance_valid(sun_light):
		# global_transform.basis.z points directly towards the sun source in Godot 3D
		var sun_dir: Vector3 = sun_light.global_transform.basis.z.normalized()
		sky_mat.set_shader_parameter("sun_direction", sun_dir)
		
		# Compute the precise day/night blend (positive Y means above the horizon/day)
		var day_weight: float = clamp(sun_dir.y * 4.0 + 0.2, 0.0, 1.0)
		sky_mat.set_shader_parameter("day_weight", day_weight)
		
	# 2. Synchronize the Moon's position
	if is_instance_valid(moon_light):
		var moon_dir: Vector3 = moon_light.global_transform.basis.z.normalized()
		sky_mat.set_shader_parameter("moon_direction", moon_dir)
		
	# 3. Synchronize the smooth weather storm cloud cover
	sky_mat.set_shader_parameter("storm_weight", _current_storm_weight)

## Public helper: Returns true if it is currently nighttime
func is_night_time() -> bool:
	return _current_time < 0.2 or _current_time > 0.8

## Public API: Returns the current descriptive moon phase name based on the calendar
func get_moon_phase_name() -> String:
	if _calendar_days == 14:
		return "Full Moon"
	elif _calendar_days == 1 or _calendar_days == 28:
		return "New Moon"
	elif _calendar_days < 7:
		return "Waxing Crescent"
	elif _calendar_days == 7:
		return "First Quarter"
	elif _calendar_days < 14:
		return "Waxing Crescent"
	elif _calendar_days >= 15 and _calendar_days < 21:
		return "Waning Gibbous"
	elif _calendar_days == 21:
		return "Third Quarter"
	else:
		return "Waning Crescent"

## Public API: Converts the internal 0..1 timeline into a formatted digital 24h clock string (HH:MM)
func get_formatted_time() -> String:
	var total_minutes := int(floor(_current_time * 1440.0))
	var hours := int(float(total_minutes) / 60.0)
	var minutes := int(total_minutes % 60)
	return "%02d:%02d" % [hours, minutes]
