# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic SunLight and MoonLight rotation, and procedural sky transitions.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Only manages physical orbits
#   and day timelines, delegating weather-uniform parameters to the GPU.
# BUG FIX:
# - Weather Node Defensive Parsing: Added strict variant checking (`!= null`)
#   when pulling weather settings to block the `Nonexistent int constructor` 
#   GDScript engine crash in generic fallback routines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Celestial/CelestialService.gd
# ==============================================================================
class_name CelestialService
extends Node

## Static instance provider for global access without SceneTree traversal
static var instance: CelestialService = null

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


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


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
	
	# Fade sun in/out based on daylight limits (Sunrise 5:45 AM / Sunset 6:15 PM)
	var is_night: bool = _current_time < 0.24 or _current_time > 0.76
	if is_night:
		sun_light.light_energy = 0.0
		sun_light.shadow_enabled = false
	else:
		var intensity: float = 1.2
		if _current_time < 0.32: # Sunrise fade (0.24 to 0.32)
			intensity = remap(_current_time, 0.24, 0.32, 0.0, 1.2)
		elif _current_time > 0.68: # Sunset fade (0.68 to 0.76)
			intensity = remap(_current_time, 0.68, 0.76, 1.2, 0.0)
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
	
	# Verify if it is currently nighttime (Sunrise 5:45 AM / Sunset 6:15 PM)
	var is_night: bool = _current_time < 0.24 or _current_time > 0.76
	if not is_night:
		moon_light.light_energy = 0.0
		moon_light.shadow_enabled = false
	else:
		var moon_phase_mult: float = 1.0 - abs((float(_calendar_days) - 14.0) / 14.0)
		
		# Fade moon energy smoothly during transitions (Sunset/Sunrise)
		var max_intensity: float = 0.06 * moon_phase_mult
		var intensity: float = max_intensity
		
		if _current_time > 0.76 and _current_time < 0.84: # Sunset rise (0.76 to 0.84)
			intensity = remap(_current_time, 0.76, 0.84, 0.0, max_intensity)
		elif _current_time < 0.24 and _current_time > 0.16: # Sunrise set (0.16 to 0.24)
			intensity = remap(_current_time, 0.16, 0.24, max_intensity, 0.0)
			
		moon_light.light_energy = clamp(intensity, 0.0, 0.06)
		moon_light.shadow_enabled = moon_light.light_energy > 0.01


## Queries the Weather Service sibling and interpolates storm overcast weights
func _process_weather_transitions(delta: float) -> void:
	var weather_node: Node = get_parent().get_node_or_null("WeatherService") as Node
	var target_storm: float = 0.0
	
	if is_instance_valid(weather_node):
		# DEFENSIVE CASTING: Safely extract variant, preventing int(null) crash!
		var cur_weather: Variant = weather_node.get("current_weather")
		if cur_weather != null:
			var w_type: int = int(cur_weather)
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
	return _current_time < 0.24 or _current_time > 0.76


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


# ==============================================================================
# STATIC SERVICE LOCATOR INTERFACES (DIP COMPLIANT)
# ==============================================================================

## Static helper to query nighttime state safely from any script context
static func is_night_time_static() -> bool:
	if is_instance_valid(instance):
		return instance.is_night_time()
	return false


## Static helper to query clock formatting safely from any script context
static func get_formatted_time_static() -> String:
	if is_instance_valid(instance):
		return instance.get_formatted_time()
	return "12:00"
