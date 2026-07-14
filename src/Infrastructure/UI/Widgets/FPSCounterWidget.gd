# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd
# Description: SRP-compliant UI Widget responsible for updating the FPS label.
#              SOLID COMPLIANCE: Updates throttled strictly to 20Hz (0.05s interval)
#              to reduce Main Thread CPU overhead in accordance with Rule 7.2.
#              Corrected: Explicit int() cast to avoid narrowing conversion warning.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FPSCounterWidget
extends Label

const THROTTLE_INTERVAL_SEC: float = 0.05

var _accumulated_delta: float = 0.0


func _process(delta: float) -> void:
	_accumulated_delta += delta
	if _accumulated_delta >= THROTTLE_INTERVAL_SEC:
		_accumulated_delta = 0.0
		_update_performance_telemetry()


func _update_performance_telemetry() -> void:
	var fps: int = int(Engine.get_frames_per_second())
	text = tr("HUD_FPS") + ": " + str(fps)
	
	if label_settings != null:
		_apply_performance_colors(fps)


func _apply_performance_colors(fps: int) -> void:
	if fps >= 55:
		label_settings.font_color = Color(0.2, 1.0, 0.2) # Green (Optimal)
	elif fps >= 30:
		label_settings.font_color = Color(1.0, 0.85, 0.2) # Yellow (Minor Drop)
	else:
		label_settings.font_color = Color(1.0, 0.2, 0.2) # Red (Lag Alert)
