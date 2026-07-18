# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd
# Description: Real-time, instant performance counter with a rolling average filter (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FPSCounterWidget
extends Label

const THROTTLE_INTERVAL_SEC: float = 0.05
const HISTORY_MAX_SIZE: int = 12

var _accumulated_delta: float = 0.0
var _frame_times_history: Array[float] = []


func _process(delta: float) -> void:
	_frame_times_history.append(delta)
	if _frame_times_history.size() > HISTORY_MAX_SIZE:
		_frame_times_history.remove_at(0)
		
	_accumulated_delta += delta
	if _accumulated_delta >= THROTTLE_INTERVAL_SEC:
		_accumulated_delta = 0.0
		_update_performance_telemetry()


func _update_performance_telemetry() -> void:
	if _frame_times_history.is_empty():
		return
		
	var sum := 0.0
	for t: float in _frame_times_history:
		sum += t
		
	var average_frame_time := sum / float(_frame_times_history.size())
	var fps: int = 0
	
	if average_frame_time > 0.0001:
		fps = int(round(1.0 / average_frame_time))
		
	text = tr("HUD_FPS") + ": " + str(fps)
	
	if label_settings != null:
		_apply_performance_colors(fps)


func _apply_performance_colors(fps: int) -> void:
	if fps >= 110:
		label_settings.font_color = Color(0.2, 1.0, 0.2) # Green (Optimal)
	elif fps >= 60:
		label_settings.font_color = Color(1.0, 0.85, 0.2) # Yellow (Minor Drop)
	else:
		label_settings.font_color = Color(1.0, 0.2, 0.2) # Red (Lag Alert)
