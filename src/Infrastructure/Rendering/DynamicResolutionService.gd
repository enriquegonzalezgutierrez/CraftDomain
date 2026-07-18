# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/DynamicResolutionService.gd
# Description: Infrastructure Service managing dynamic resolution scaling (DRS)
#              with automatic screen refresh-rate detection and a 120Hz minimum target (DIP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DynamicResolutionService
extends Node

const MIN_RESOLUTION_SCALE: float = 0.65
const MAX_RESOLUTION_SCALE: float = 1.00

const SCALE_DOWN_STEP: float = 0.05
const SCALE_UP_STEP: float = 0.01
const EVALUATION_INTERVAL_SEC: float = 0.15

var _viewport: Viewport
var _elapsed_time: float = 0.0

# Dynamic performance thresholds calculated on ready based on monitor hardware
var _target_frame_time_sec: float = 0.00833 # Fallback 120 FPS
var _safe_frame_time_sec: float = 0.00700   # Fallback 142 FPS


func _ready() -> void:
	name = "DynamicResolutionService"
	_viewport = get_viewport()
	_elapsed_time = 0.0
	_initialize_viewport_rendering_properties()


func _process(delta: float) -> void:
	if not is_instance_valid(_viewport):
		return
		
	_elapsed_time += delta
	if _elapsed_time >= EVALUATION_INTERVAL_SEC:
		_elapsed_time = 0.0
		_evaluate_performance_metrics()


func _initialize_viewport_rendering_properties() -> void:
	if not is_instance_valid(_viewport):
		return
		
	var adapter_name := RenderingServer.get_video_adapter_name().to_lower()
	var is_software := _is_adapter_software_rasterizer(adapter_name)
	
	if is_software:
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		print("[DRS] Software rasterizer detected. Bypassed FSR 2.2 to use Bilinear scaling.")
	else:
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		print("[DRS] Dedicated/Integrated GPU detected. Initialized under FSR 2.2 upscaling.")
		
	_viewport.scaling_3d_scale = MAX_RESOLUTION_SCALE
	_calculate_dynamic_performance_thresholds()


func _calculate_dynamic_performance_thresholds() -> void:
	var screen_hz := DisplayServer.screen_get_refresh_rate()
	if screen_hz <= 0.0:
		screen_hz = 120.0
		
	# Symmetrical Protection Floor: Set a minimum target of 120Hz to protect 120 FPS
	var target_hz := maxf(120.0, screen_hz)
	
	_target_frame_time_sec = 1.0 / (target_hz - 10.0)
	_safe_frame_time_sec = 1.0 / (target_hz - 2.0)
	
	print("[DRS] Screen: %dHz | Target HZ: %dHz. Target: %.2fms, Recovery: %.2fms" % [
		int(screen_hz), 
		int(target_hz),
		_target_frame_time_sec * 1000.0, 
		_safe_frame_time_sec * 1000.0
	])


func _is_adapter_software_rasterizer(adapter_name: String) -> bool:
	return (
		adapter_name.contains("llvmpipe") or 
		adapter_name.contains("swiftshader") or 
		adapter_name.contains("software")
	)


func _evaluate_performance_metrics() -> void:
	var fps := Engine.get_frames_per_second()
	if fps <= 0:
		return
		
	var average_frame_time := 1.0 / float(fps)
	var current_scale := _viewport.scaling_3d_scale
	
	if average_frame_time > _target_frame_time_sec:
		_decrease_resolution(current_scale, average_frame_time)
	elif average_frame_time < _safe_frame_time_sec:
		_increase_resolution(current_scale, average_frame_time)


func _decrease_resolution(current_scale: float, frame_time: float) -> void:
	var target_scale := clampf(current_scale - SCALE_DOWN_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if target_scale != current_scale:
		_viewport.scaling_3d_scale = target_scale
		print("[DRS Debug] Performance Strain: %.2fms. Scaling down viewport to: %.2f" % [frame_time * 1000.0, target_scale])


func _increase_resolution(current_scale: float, frame_time: float) -> void:
	var target_scale := clampf(current_scale + SCALE_UP_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if target_scale != current_scale:
		_viewport.scaling_3d_scale = target_scale
		print("[DRS Debug] Performance Restored: %.2fms. Scaling up viewport to: %.2f" % [frame_time * 1000.0, target_scale])
