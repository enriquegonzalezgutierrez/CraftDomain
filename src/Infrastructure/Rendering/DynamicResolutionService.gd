# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/DynamicResolutionService.gd
# Description: Infrastructure Service managing dynamic resolution scaling (DRS)
#              with optimized FSR 2.2 and Bilinear fallbacks.
#              HARDWARE GUARDRAIL: Automatically bypasses FSR 2.2 compute scaling
#              on Integrated/Software GPUs (Intel UHD) to prevent driver crashes
#              in fsr2.cpp, falling back to ultra-stable Bilinear scaling.
#              EXIT SAFEGUARD: Intercepts destruction notifications to prevent
#              out-of-order X11 window geometry queries during shutdown.
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

# Symmetrical constants to bypass unexposed Godot 4 C++ DeviceType enums
const ADAPTER_TYPE_INTEGRATED: int = 1
const ADAPTER_TYPE_CPU: int = 4

var _viewport: Viewport
var _elapsed_time: float = 0.0

var _target_frame_time_sec: float = 0.00833 
var _safe_frame_time_sec: float = 0.00700   
var _current_scale: float = 1.0


func _ready() -> void:
	name = "DynamicResolutionService"
	_viewport = get_viewport()
	_elapsed_time = 0.0
	_initialize_viewport_rendering_properties()


func _notification(what: int) -> void:
	# Intercept close requests to halt processing instantly, avoiding X11 BadWindow errors
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		set_process(false)


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
		
	var adapter_type := RenderingServer.get_video_adapter_type()
	var is_low_end := (
		adapter_type == ADAPTER_TYPE_INTEGRATED or 
		adapter_type == ADAPTER_TYPE_CPU
	)
	
	_configure_scaling_mode(is_low_end)
	
	_viewport.scaling_3d_scale = MAX_RESOLUTION_SCALE
	_current_scale = MAX_RESOLUTION_SCALE
	_calculate_dynamic_performance_thresholds()


func _configure_scaling_mode(is_low_end: bool) -> void:
	if is_low_end:
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		print("[DRS] Integrated/Software GPU detected. Bypassed FSR 2 to prevent C++ driver crashes.")
	else:
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		print("[DRS] Dedicated GPU detected. Initialized under FSR 2 upscaling.")


func _calculate_dynamic_performance_thresholds() -> void:
	var screen_hz := DisplayServer.screen_get_refresh_rate()
	if screen_hz <= 0.0:
		screen_hz = 60.0
		
	_target_frame_time_sec = 1.0 / maxf(10.0, screen_hz - 10.0)
	_safe_frame_time_sec = 1.0 / maxf(10.0, screen_hz - 2.0)
	
	print("[DRS] Screen: %dHz | Scaled target at: %.2fms, Recovery: %.2fms" % [
		int(screen_hz), 
		_target_frame_time_sec * 1000.0, 
		_safe_frame_time_sec * 1000.0
	])


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
