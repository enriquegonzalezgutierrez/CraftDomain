# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd
# Description: Real-time, high-fidelity performance counter utilizing Godot's 
#              native C++ Performance monitor. This completely filters out 
#              isolated frame-stall outliers, presenting the true visual FPS 
#              experienced by the player on any hardware.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively queries and formats 
#   the active rendering frame-rate.
# ==============================================================================
class_name FPSCounterWidget
extends Label

const TEXT_UPDATE_INTERVAL: float = 0.25 # Refresh the UI 4 times per second to prevent text flicker
var _accumulated_time: float = 0.0


func _process(delta: float) -> void:
	_accumulated_time += delta
	if _accumulated_time >= TEXT_UPDATE_INTERVAL:
		_accumulated_time = 0.0
		_update_performance_label()


func _update_performance_label() -> void:
	# Query the exact C++ engine rendering FPS (filters out single-frame outliers)
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	
	text = tr("HUD_FPS") + ": " + str(fps)
	
	if label_settings != null:
		_apply_performance_colors(fps)


func _apply_performance_colors(fps: int) -> void:
	# Dynamic visual alerts based on target framerates
	if fps >= 110:
		label_settings.font_color = Color(0.2, 1.0, 0.2) # Green (Optimal 120Hz)
	elif fps >= 55:
		label_settings.font_color = Color(1.0, 0.85, 0.2) # Yellow (Target 60Hz)
	else:
		label_settings.font_color = Color(1.0, 0.15, 0.15) # Red (Lag Warning)
