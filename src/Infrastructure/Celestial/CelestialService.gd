# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic SunLight and MoonLight rotation, and procedural sky transitions.
#              SOLID COMPLIANCE: Encapsulates all dynamic celestial calculations.
#              FIXED: Explicitly declared static types (float) for moon phase 
#              and light intensity calculations to satisfy strict static compiler rules.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Celestial/CelestialService.gd
# ==============================================================================
class_name CelestialService
extends Node

## Speed of time progression (72.0 multiplier makes a full day last exactly 20 minutes)
var time_speed: float = 72.0

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

# Sky colors for different times of day
const SKY_COLORS = {
	"MORNING_TOP": Color(0.2, 0.55, 0.9),      
	"MORNING_HORIZON": Color(0.95, 0.75, 0.45), 
	
	"NOON_TOP": Color(0.12, 0.45, 0.95),       
	"NOON_HORIZON": Color(0.55, 0.85, 1.0),    
	
	"SUNSET_TOP": Color(0.15, 0.25, 0.45),     
	"SUNSET_HORIZON": Color(0.95, 0.45, 0.2),  
	
	"NIGHT_TOP": Color(0.02, 0.02, 0.08),      
	"NIGHT_HORIZON": Color(0.08, 0.08, 0.15)   
}

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
	
	add_child(moon_light)

func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light):
		return
		
	var angle_rad: float = (_current_time * TAU) - (PI / 2.0)
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
	var angle_rad: float = (_current_time * TAU) - (PI / 2.0) + PI
	moon_light.rotation.x = angle_rad
	moon_light.rotation.y = deg_to_rad(-145) # Azimuth opposite angle
	
	# Verify if it is currently nighttime
	var is_night: bool = _current_time < 0.22 or _current_time > 0.78
	if not is_night:
		moon_light.light_energy = 0.0
		moon_light.shadow_enabled = false
	else:
		# FIXED: Declared strict types (float) to prevent Variant type propagation errors
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

func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment):
		return
		
	var sky: Sky = world_environment.environment.sky
	if sky == null or not (sky.sky_material is ProceduralSkyMaterial):
		return
		
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	
	var top_color: Color
	var horizon_color: Color
	
	if _current_time < 0.25:
		var t := remap(_current_time, 0.0, 0.25, 0.0, 1.0)
		top_color = SKY_COLORS["NIGHT_TOP"].lerp(SKY_COLORS["MORNING_TOP"], t)
		horizon_color = SKY_COLORS["NIGHT_HORIZON"].lerp(SKY_COLORS["MORNING_HORIZON"], t)
	elif _current_time < 0.5:
		var t := remap(_current_time, 0.25, 0.5, 0.0, 1.0)
		top_color = SKY_COLORS["MORNING_TOP"].lerp(SKY_COLORS["NOON_TOP"], t)
		horizon_color = SKY_COLORS["MORNING_HORIZON"].lerp(SKY_COLORS["NOON_HORIZON"], t)
	elif _current_time < 0.75:
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
		return "Waxing Gibbous"
	elif _calendar_days < 21:
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
