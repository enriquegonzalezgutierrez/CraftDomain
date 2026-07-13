# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/FlightInstrumentsWidget.gd
# Description: Symmetrical HUD flight instrument widget displaying real-time 
#              airspeed, altitude, and glide ratio during flight.
#              Corrected: Sourced all UI strings through tr() (Section 5.2).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FlightInstrumentsWidget
extends Control

@export var player: CharacterBody3D

@onready var _airspeed_label: Label = $VBoxContainer/AirspeedLabel
@onready var _altitude_label: Label = $VBoxContainer/AltitudeLabel
@onready var _ratio_label: Label = $VBoxContainer/RatioLabel


func _ready() -> void:
	visible = false


## Throttled update cycle triggered from the main PlayerHUD loop at 20Hz (SRP)
func update_widget() -> void:
	if not is_instance_valid(player) or not player.get("is_glider_deployed") as bool:
		visible = false
		return
		
	visible = true
	var vel: Vector3 = player.velocity
	var speed_flat := Vector2(vel.x, vel.z).length()
	var speed_total := vel.length()
	
	_airspeed_label.text = tr("FLIGHT_AIRSPEED") % speed_total
	_altitude_label.text = tr("FLIGHT_ALTITUDE") % int(round(player.global_position.y))
	
	# Calculate glide ratio (horizontal speed over vertical sink rate)
	if absf(vel.y) > 0.05:
		var ratio := speed_flat / absf(vel.y)
		_ratio_label.text = tr("FLIGHT_GLIDE_RATIO") % ratio
	else:
		_ratio_label.text = tr("FLIGHT_RATIO_STABLE")
