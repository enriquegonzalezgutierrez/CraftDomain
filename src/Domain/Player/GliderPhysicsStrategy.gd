# ==============================================================================
# Pathfile: res://src/Domain/Player/GliderPhysicsStrategy.gd
# Description: Pure Domain strategy calculating aerodynamic forces, lift/drag
#              coefficients, and velocity translations for glider flight.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GliderPhysicsStrategy
extends RefCounted

# Aerodynamic constants to avoid magic numbers
const GRAVITY_GLIDE_LIMIT: float = -2.5       # Terminal sink rate under optimal glide (m/s)
const GRAVITY_FALL_ACCEL: float = -9.8        # Standard gravity acceleration fallback
const LIFT_COEFFICIENT_MAX: float = 1.45       # Maximum lift coefficient at optimal angle of attack
const DRAG_COEFFICIENT_MIN: float = 0.08       # Parasitic drag of the wooden glider structure
const AIR_DENSITY_STRATOSPHERE: float = 1.225  # Air density constant (kg/m^3)
const GLIDER_WING_AREA: float = 12.0           # Effective wing surface area (m^2)

# Tilt/Pitch threshold constants
const OPTIMAL_GLIDE_PITCH_DEG: float = -10.0  # Optimal pitch angle for maximum lift-to-drag ratio
const STALL_PITCH_DEG: float = 25.0           # Pitch angle where lift collapses and glider stalls


## Calculates the resulting 3D velocity vector during glider flight.
## Integrates kinetic energy conversion based on look direction pitch and wind influence.
func calculate_glide_velocity(
	current_velocity: Vector3,
	look_direction: Vector3,
	wind_vector: Vector2,
	wind_strength: float,
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
		
	# 2. Evaluate Aerodynamic Coefficients based on Pitch Angle of Attack
	var lift_coef := _calculate_lift_coefficient(pitch_angle_deg)
	var drag_coef := _calculate_drag_coefficient(pitch_angle_deg)
	
	# 3. Calculate Lift and Drag Forces
	var dynamic_pressure := 0.5 * AIR_DENSITY_STRATOSPHERE * (airspeed * airspeed)
	var lift_force_mag := dynamic_pressure * GLIDER_WING_AREA * lift_coef
	var drag_force_mag := dynamic_pressure * GLIDER_WING_AREA * drag_coef
	
	# 4. Apply Forces to Velocity
	var lift_direction := Vector3.UP
	
	# If moving forward, lift acts perpendicular to relative velocity
	if airspeed > 1.0:
		var relative_dir := relative_velocity.normalized()
		var lateral_axis := relative_dir.cross(Vector3.UP).normalized()
		lift_direction = lateral_axis.cross(relative_dir).normalized()
		
	var drag_force_vector := -relative_velocity.normalized() * drag_force_mag
	var lift_force_vector := lift_direction * lift_force_mag
	
	var total_forces := lift_force_vector + drag_force_vector
	var resulting_velocity := current_velocity + (total_forces * delta)
	
	# 5. Apply Gravity Compensation & Glide Sink Rate limits
	# Pitching down gains forward speed from potential energy. Pitching up converts speed to altitude.
	if pitch_angle_deg < 0.0:
		# Gliding downwards: convert altitude drop to horizontal thrust
		var descent_ratio := clampf(abs(pitch_angle_deg) / 45.0, 0.0, 1.0)
		resulting_velocity.y = lerp(GRAVITY_GLIDE_LIMIT, GRAVITY_FALL_ACCEL * 0.8, descent_ratio)
	else:
		# Pitching upwards: bleed speed to gain temporary lift climb
		var climb_ratio := clampf(pitch_angle_deg / STALL_PITCH_DEG, 0.0, 1.0)
		var speed_bleed_factor := 1.0 - (climb_ratio * 0.8)
		resulting_velocity.x *= speed_bleed_factor
		resulting_velocity.z *= speed_bleed_factor
		resulting_velocity.y = lerp(GRAVITY_GLIDE_LIMIT, 2.5, climb_ratio * (airspeed / 10.0))
		
		# Stall condition: speed collapsed under pitch stress
		if airspeed < 3.0:
			resulting_velocity.y = GRAVITY_FALL_ACCEL
			resulting_velocity.x *= 0.5
			resulting_velocity.z *= 0.5
			
	return resulting_velocity


## Helper: Calculates Lift Coefficient (Cl) based on pitch angle of attack.
func _calculate_lift_coefficient(pitch_deg: float) -> float:
	if pitch_deg >= STALL_PITCH_DEG:
		return 0.1 # Stalled flight loses lift
		
	# Standard symmetrical wing lift curve approximation
	var normalized_pitch := (pitch_deg - OPTIMAL_GLIDE_PITCH_DEG) / (STALL_PITCH_DEG - OPTIMAL_GLIDE_PITCH_DEG)
	var lift_ratio := sin(normalized_pitch * PI * 0.5)
	return clampf(lift_ratio * LIFT_COEFFICIENT_MAX, -0.2, LIFT_COEFFICIENT_MAX)


## Helper: Calculates Drag Coefficient (Cd) based on pitch. Induced drag rises with pitch.
func _calculate_drag_coefficient(pitch_deg: float) -> float:
	var abs_pitch := absf(pitch_deg)
	var induced_drag_ratio := clampf(abs_pitch / 45.0, 0.0, 1.0)
	return DRAG_COEFFICIENT_MIN + (induced_drag_ratio * induced_drag_ratio * 0.45)
