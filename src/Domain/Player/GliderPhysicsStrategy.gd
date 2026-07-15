# ==============================================================================
# Pathfile: res://src/Domain/Player/GliderPhysicsStrategy.gd
# Description: Pure Domain strategy calculating physical aerodynamic forces, 
#              lift/drag vectors, and kinetic/potential energy conversions 
#              for realistic glider flight.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates flight-sim 
#   vector aerodynamics, fully independent of presentation views and input buffers.
# - Open-Closed Principle (OCP): Dynamic atmospheric density factor varies 
#   automatically by altitude, requiring no changes on weather controllers.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GliderPhysicsStrategy
extends RefCounted

# Aerodynamic constants to avoid magic numbers (SOLID compliance)
const GRAVITY_FALL_ACCEL: float = -9.8        # Standard gravity acceleration (m/s^2)
const LIFT_COEFFICIENT_MAX: float = 1.45       # Maximum lift coefficient at optimal angle of attack
const DRAG_COEFFICIENT_MIN: float = 0.08       # Parasitic drag of the wooden wing structure
const AIR_DENSITY_SEA_LEVEL: float = 1.225     # Sea level air density constant (kg/m^3)
const GLIDER_WING_AREA: float = 12.0           # Effective glider wing surface area (m^2)
const PLAYER_MASS_KG: float = 80.0             # Combined mass of player + wood gear (kg)

# Tilt/Pitch threshold constants
const OPTIMAL_GLIDE_PITCH_DEG: float = -10.0  # Optimal pitch angle for maximum lift-to-drag ratio
const STALL_PITCH_DEG: float = 25.0           # Pitch angle where lift collapses and glider stalls
const STALL_AIRSPEED_LIMIT: float = 3.5       # Minimum airspeed required to maintain lift (m/s)


## Computes the resulting 3D velocity vector during glider flight.
## Integrates kinetic energy conversion based on look direction pitch and wind influence.
func calculate_glide_velocity(
	current_velocity: Vector3,
	look_direction: Vector3,
	wind_vector: Vector2,
	wind_strength: float,
	global_y: float,
	delta: float
) -> Vector3:
	var pitch_angle_deg := rad_to_deg(asin(look_direction.y))
	
	# 1. Resolve Wind vector translation
	var wind_3d := Vector3(wind_vector.x, 0.0, wind_vector.y) * wind_strength
	var relative_velocity := current_velocity - wind_3d
	var airspeed := relative_velocity.length()
	
	# Prevent divide-by-zero on initial launch stillness
	if airspeed < 0.1:
		airspeed = 0.1
		
	# 2. Dynamic Air Density calculation based on Altitude (Thin air at Y >= 30)
	var density_factor := clampf(1.0 - (global_y / 60.0), 0.35, 1.0)
	var active_density := AIR_DENSITY_SEA_LEVEL * density_factor
	
	# 3. Calculate Lift and Drag Coefficients
	var is_stalled := (pitch_angle_deg >= STALL_PITCH_DEG) or (airspeed < STALL_AIRSPEED_LIMIT)
	var lift_coef := _calculate_lift_coefficient(pitch_angle_deg, is_stalled)
	var drag_coef := _calculate_drag_coefficient(pitch_angle_deg, is_stalled)
	
	# 4. Calculate Aerodynamic Force Magnitudes
	var dynamic_pressure := 0.5 * active_density * (airspeed * airspeed)
	var lift_mag := dynamic_pressure * GLIDER_WING_AREA * lift_coef
	var drag_mag := dynamic_pressure * GLIDER_WING_AREA * drag_coef
	
	# 5. Resolve Force Directional Vectors
	var drag_dir := -relative_velocity.normalized()
	var lift_dir := Vector3.UP
	
	if airspeed > 0.5:
		var forward_dir := relative_velocity.normalized()
		var right_dir := forward_dir.cross(Vector3.UP).normalized()
		lift_dir = right_dir.cross(forward_dir).normalized()
		
	var lift_force := lift_dir * lift_mag
	var drag_force := drag_dir * drag_mag
	var gravity_force := Vector3.DOWN * absf(GRAVITY_FALL_ACCEL) * PLAYER_MASS_KG
	
	# 6. Apply Newton-Euler Vector Acceleration: F_total = F_lift + F_drag + F_gravity
	var total_forces := lift_force + drag_force + gravity_force
	var acceleration := total_forces / PLAYER_MASS_KG
	var resulting_velocity := current_velocity + (acceleration * delta)
	
	return resulting_velocity


## Helper: Calculates Lift Coefficient (Cl) based on pitch and stall conditions
func _calculate_lift_coefficient(pitch_deg: float, is_stalled: bool) -> float:
	if is_stalled:
		return 0.12 # Lift collapses during a stall
		
	# Standard symmetrical wing lift curve approximation
	var normalized_pitch := (pitch_deg - OPTIMAL_GLIDE_PITCH_DEG) / (STALL_PITCH_DEG - OPTIMAL_GLIDE_PITCH_DEG)
	var lift_ratio := sin(normalized_pitch * PI * 0.5)
	return clampf(lift_ratio * LIFT_COEFFICIENT_MAX, -0.1, LIFT_COEFFICIENT_MAX)


## Helper: Calculates Drag Coefficient (Cd). Induced drag rises significantly during stall
func _calculate_drag_coefficient(pitch_deg: float, is_stalled: bool) -> float:
	var abs_pitch := absf(pitch_deg)
	var induced_drag_ratio := clampf(abs_pitch / 45.0, 0.0, 1.0)
	var base_drag := DRAG_COEFFICIENT_MIN + (induced_drag_ratio * induced_drag_ratio * 0.35)
	
	if is_stalled:
		return base_drag * 2.2 # Drag spikes when the wing stalls
		
	return base_drag
