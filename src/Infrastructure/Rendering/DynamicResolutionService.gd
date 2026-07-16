# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/DynamicResolutionService.gd
# Description: Infrastructure Service managing dynamic resolution scaling (DRS)
#              interfaced with Godot's FSR 2.2 temporal upscaler.
#              Monitors frame time budgets and adjusts 3D viewport scales
#              asymmetrically to protect and sustain a locked 120 FPS runtime.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates performance
#   monitoring and dynamic viewport scale clamping. All methods kept < 20 lines.
# - Open-Closed Principle (OCP): Operates autonomously as a SceneTree observer,
#   requiring zero code alterations to existing rendering or player scripts.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DynamicResolutionService
extends Node

# 120 FPS target budget (1000ms / 120 FPS = 8.33ms)
const TARGET_FRAME_TIME_SEC: float = 0.00833

# Safe frame budget threshold to trigger gradual resolution recovery (7.00ms)
const SAFE_FRAME_TIME_SEC: float = 0.00700

# Clamp scale parameters (FSR 2.2 behaves beautifully at 65% internal scale)
const MIN_RESOLUTION_SCALE: float = 0.65
const MAX_RESOLUTION_SCALE: float = 1.00

# Asymmetrical steps: decrease rapidly on frame drops, recover very slowly
const SCALE_DOWN_STEP: float = 0.05
const SCALE_UP_STEP: float = 0.01

# Throttled evaluation polling rate (10Hz) to prevent visual jittering
const EVALUATION_INTERVAL_SEC: float = 0.1

var _viewport: Viewport
var _elapsed_time: float = 0.0


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
	if is_instance_valid(_viewport):
		# Ensure FSR 2.2 is set as the active 3D upscaler
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_viewport.scaling_3d_scale = MAX_RESOLUTION_SCALE
		print("[DRS] Dynamic Resolution Service initialized under FSR 2.2 upscaling.")


func _evaluate_performance_metrics() -> void:
	# Query the actual frame processing time (CPU + GPU sync time) in seconds
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) as float
	var current_scale := _viewport.scaling_3d_scale
	
	if frame_time > TARGET_FRAME_TIME_SEC:
		_decrease_resolution(current_scale)
	elif frame_time < SAFE_FRAME_TIME_SEC:
		_increase_resolution(current_scale)


func _decrease_resolution(current_scale: float) -> void:
	var target_scale := clampf(current_scale - SCALE_DOWN_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if target_scale != current_scale:
		_viewport.scaling_3d_scale = target_scale
		# print("[DRS] Frame drop detected. Decreasing internal scale to: ", target_scale)


func _increase_resolution(current_scale: float) -> void:
	var target_scale := clampf(current_scale + SCALE_UP_STEP, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
	if target_scale != current_scale:
		_viewport.scaling_3d_scale = target_scale
