# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/DynamicResolutionService.gd
# Description: Infrastructure Service managing dynamic resolution scaling (DRS)
#              with CPU-side scale caching and optimized FSR 2.2 quality bounds.
#              PERFORMANCE & VISUAL UPGRADE: Replaced forced 120Hz calculations 
#              with actual monitor refresh rate sweeps to prevent aggressive 
#              downscaling and blurry graphics on 60Hz screens.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DynamicResolutionService
extends Node

const MIN_RESOLUTION_SCALE: float = 0.65 
const MAX_RESOLUTION_SCALE: float = 1.00

const SCALE_DOWN_STEP: float = 0.15      
const SCALE_UP_STEP: float = 0.02        
const EVALUATION_INTERVAL_SEC: float = 0.12 

var _viewport: Viewport
var _elapsed_time: float = 0.0

# Dynamic performance thresholds calculated on ready based on monitor hardware
var _target_frame_time_sec: float = 0.00833 
var _safe_frame_time_sec: float = 0.00700   

# CPU-side scale cache to prevent redundant rendering queries and float mismatches
var _current_scale: float = 1.0


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
	_current_scale = MAX_RESOLUTION_SCALE
	_calculate_dynamic_performance_thresholds()


func _calculate_dynamic_performance_thresholds() -> void:
	var screen_hz := DisplayServer.screen_get_refresh_rate()
	if screen_hz <= 0.0:
		screen_hz = 60.0 # Default safe fallback
		
	# SENSITIVITY FIX: Target the actual hardware monitor refresh rate (screen_hz)
	# instead of forcing 120Hz, preventing aggressive blurry downscaling on 60Hz screens.
	_target_frame_time_sec = 1.0 / maxf(10.0, screen_hz - 10.0)
	_safe_frame_time_sec = 1.0 / maxf(10.0, screen_hz - 2.0)
	
	print("[DRS] Screen: %dHz | Scaled target at: %.2fms, Recovery: %.2fms" % [
		int(screen_hz), 
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
	
	if average_frame_time > _target_frame_time_sec:
		_decrease_resolution(_current_scale)
	elif average_frame_time < _safe_frame_time_sec:
		_increase_resolution(_current_scale)


func _decrease_resolution(current_scale: float) -> void:
	var target_scale := clampf(current_scale - SCALE_DOWN_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if absf(target_scale - current_scale) > 0.001:
		_current_scale = target_scale
		_viewport.scaling_3d_scale = target_scale


func _increase_resolution(current_scale: float) -> void:
	var target_scale := clampf(current_scale + SCALE_UP_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if absf(target_scale - current_scale) > 0.001:
		_current_scale = target_scale
		_viewport.scaling_3d_scale = target_scale
