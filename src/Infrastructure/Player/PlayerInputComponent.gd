# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerInputComponent.gd
# Description: Infrastructure Component responsible ONLY for capturing raw hardware
#              keyboard/mouse actions, exposing a clean API to PlayerController (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerInputComponent
extends Node

var host: CharacterBody3D


## Injects the player host node reference and registers inputs inside Godot's InputMap
func initialize(p_host: CharacterBody3D) -> void:
	host = p_host
	_setup_inputs_map()


## Returns the responsive 2D movement vector (WASD / Arrows)
func get_movement_vector() -> Vector2:
	if not is_instance_valid(host) or not host.get("is_active") as bool:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


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
