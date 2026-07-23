# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/VirtualControllerWidget.gd
# Description: Platform-aware virtual touchscreen overlay containing joysticks
#              for mobile inputs. Emulates standard hardware Gamepad axis inputs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VirtualControllerWidget
extends Control

@export var player: CharacterBody3D

@onready var _left_zone: Panel = $LeftJoystickZone
@onready var _left_handle: Panel = $LeftJoystickZone/Handle

@onready var _right_zone: Panel = $RightJoystickZone
@onready var _right_handle: Panel = $RightJoystickZone/Handle

# Multi-touch tracking maps: Touch Index (int) -> Joystick Side ("left" or "right")
var _active_touches: Dictionary = {}

# Joystick handle motion range radius in pixels
var _max_handle_radius: float = 60.0
var _center_offset := Vector2(60.0, 60.0)


func _ready() -> void:
	_evaluate_platform_visibility()


## Evaluates active hardware layers to determine touch controls deployment.
func _evaluate_platform_visibility() -> void:
	var is_mobile_platform := OS.has_feature("mobile")
	var is_touch_hardware_available := DisplayServer.is_touchscreen_available()
	
	if not is_mobile_platform and not is_touch_hardware_available:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		queue_free()
		return
		
	visible = true
	print("[VirtualController] Touchscreen hardware detected. Initializing overlay...")


## Intercepts multi-touch raw events and maps them to the respective virtual joysticks
func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var touch_pos := event.position
		
		# LEFT JOYSTICK HIT DETECTION
		var l_rect := _left_zone.get_global_rect()
		if l_rect.has_point(touch_pos):
			_active_touches[event.index] = "left"
			_update_joystick_vector("left", touch_pos, l_rect)
			return
			
		# RIGHT JOYSTICK HIT DETECTION
		var r_rect := _right_zone.get_global_rect()
		if r_rect.has_point(touch_pos):
			_active_touches[event.index] = "right"
			_update_joystick_vector("right", touch_pos, r_rect)
			return
			
	else:
		if _active_touches.has(event.index):
			var side: String = _active_touches[event.index]
			_active_touches.erase(event.index)
			_reset_joystick_vector(side)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _active_touches.has(event.index):
		var side: String = _active_touches[event.index]
		var rect := _left_zone.get_global_rect() if side == "left" else _right_zone.get_global_rect()
		_update_joystick_vector(side, event.position, rect)


## Calculates the clamping vector and pushes a mock Gamepad Axis event to Godot
func _update_joystick_vector(side: String, touch_pos: Vector2, zone_rect: Rect2) -> void:
	var local_pos := touch_pos - zone_rect.position
	var center := _center_offset
	
	var offset := local_pos - center
	if offset.length() > _max_handle_radius:
		offset = offset.normalized() * _max_handle_radius
		
	var handle := _left_handle if side == "left" else _right_handle
	handle.position = center + offset - (handle.size / 2.0)
	
	# Normalize output vector [-1.0, 1.0] for the physics engine
	var output_vector := offset / _max_handle_radius
	
	if side == "left":
		_inject_axis_event(JOY_AXIS_LEFT_X, output_vector.x)
		_inject_axis_event(JOY_AXIS_LEFT_Y, output_vector.y)
	else:
		_inject_axis_event(JOY_AXIS_RIGHT_X, output_vector.x)
		_inject_axis_event(JOY_AXIS_RIGHT_Y, output_vector.y)


## Resets the visual joystick to the center and stops the simulated input
func _reset_joystick_vector(side: String) -> void:
	var handle := _left_handle if side == "left" else _right_handle
	var center := _center_offset
	handle.position = center - (handle.size / 2.0)
	
	if side == "left":
		_inject_axis_event(JOY_AXIS_LEFT_X, 0.0)
		_inject_axis_event(JOY_AXIS_LEFT_Y, 0.0)
	else:
		_inject_axis_event(JOY_AXIS_RIGHT_X, 0.0)
		_inject_axis_event(JOY_AXIS_RIGHT_Y, 0.0)


## Compiles and pushes a virtual hardware Joypad event into the Godot input buffer
func _inject_axis_event(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = value
	Input.parse_input_event(event)
