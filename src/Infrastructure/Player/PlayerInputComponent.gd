# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerInputComponent.gd
# Description: Infrastructure Component responsible for capturing raw keyboard,
#              mouse, and hardware joypad/gamepad inputs (SRP).
#              Corrected: Strictly typed joypad enums (JoyAxis & JoyButton).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerInputComponent
extends Node

# Calibrated Gamepad constants to prevent drift and blowout (Section 5.3)
const GAMEPAD_DEADZONE: float = 0.15
const GAMEPAD_LOOK_SENSITIVITY: float = 2.5

var host: CharacterBody3D


## Injects the player host node reference and registers inputs inside Godot's InputMap
func initialize(p_host: CharacterBody3D) -> void:
	host = p_host
	_setup_inputs_map()


## Returns the responsive 2D movement vector (WASD / Left Stick)
func get_movement_vector() -> Vector2:
	if not is_instance_valid(host) or not host.get("is_active") as bool:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


## Returns the calculated camera rotation vector from the Right Joystick (Joypad Axis 2 & 3).
## Implements a deadzone threshold to eliminate analog drift.
func get_gamepad_look_vector() -> Vector2:
	if not is_instance_valid(host) or not host.get("is_active") as bool:
		return Vector2.ZERO
		
	# Axis 2: Right Stick X (Yaw) | Axis 3: Right Stick Y (Pitch)
	var raw_look := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	if raw_look.length() < GAMEPAD_DEADZONE:
		return Vector2.ZERO
		
	return raw_look * GAMEPAD_LOOK_SENSITIVITY


## Returns true if the spacebar jump action was triggered in this frame
func is_jump_just_pressed() -> bool:
	if not is_instance_valid(host) or not host.get("is_active") as bool:
		return false
	return Input.is_action_just_pressed("jump")


## Evaluates hotbar numerical keys [1 to 8]. Returns the chosen slot index [0 to 7], or -1 if none
func get_active_hotkey_selection() -> int:
	if not is_instance_valid(host) or not host.get("is_active") as bool:
		return -1
		
	if Input.is_action_just_pressed("select_stone"): return 0
	if Input.is_action_just_pressed("select_dirt"): return 1
	if Input.is_action_just_pressed("select_grass"): return 2
	if Input.is_action_just_pressed("select_wood"): return 3
	if Input.is_action_just_pressed("select_leaves"): return 4
	if Input.is_action_just_pressed("select_lava"): return 5
	if Input.is_action_just_pressed("select_chicken"): return 6
	if Input.is_action_just_pressed("select_sword"): return 7
	
	return -1


func _setup_inputs_map() -> void:
	var primary_inputs := {
		"move_forward": KEY_W, "move_backward": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "ui_cancel": KEY_ESCAPE, "select_stone": KEY_1, "select_dirt": KEY_2,
		"select_grass": KEY_3, "select_wood": KEY_4, "select_leaves": KEY_5, "select_lava": KEY_6,
		"select_chicken": KEY_7, "select_sword": KEY_8, "craft_item": KEY_C, "toggle_backpack": KEY_I,
		"free_cursor": KEY_ALT, "toggle_world_map": KEY_M 
	}
	for action_name: String in primary_inputs.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		var event := InputEventKey.new()
		event.keycode = primary_inputs[action_name] as Key
		InputMap.action_add_event(action_name, event)
		
	_setup_inputs_mouse_actions()
	_setup_gamepad_hardware_mappings()


func _setup_inputs_mouse_actions() -> void:
	if not InputMap.has_action("click_left"): InputMap.add_action("click_left")
	InputMap.action_erase_events("click_left")
	var left_btn := InputEventMouseButton.new(); left_btn.button_index = MOUSE_BUTTON_LEFT 
	InputMap.action_add_event("click_left", left_btn)
	var left_key := InputEventKey.new(); left_key.keycode = KEY_E
	InputMap.action_add_event("click_left", left_key)
	
	if not InputMap.has_action("click_right"): InputMap.add_action("click_right")
	InputMap.action_erase_events("click_right")
	var right_btn := InputEventMouseButton.new(); right_btn.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("click_right", right_btn)
	var right_key := InputEventKey.new(); right_key.keycode = KEY_Q
	InputMap.action_add_event("click_right", right_key)


## Maps standard physical console controls to abstract keyboard actions.
func _setup_gamepad_hardware_mappings() -> void:
	# 1. Map Left Joystick axis to movement actions
	_add_joypad_axis_mapping("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joypad_axis_mapping("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joypad_axis_mapping("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joypad_axis_mapping("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	
	# 2. Map Bottom Button (Xbox A / PS Cross) to Jump
	_add_joypad_button_mapping("jump", JOY_BUTTON_A)
	
	# 3. Map Menu Button (Xbox Start) to Escape (UI Cancel)
	_add_joypad_button_mapping("ui_cancel", JOY_BUTTON_START)
	
	# 4. Map Right/Left bumpers to quick slot scrolls
	_add_joypad_button_mapping("click_left", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joypad_button_mapping("click_right", JOY_BUTTON_LEFT_SHOULDER)


func _add_joypad_axis_mapping(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


func _add_joypad_button_mapping(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
