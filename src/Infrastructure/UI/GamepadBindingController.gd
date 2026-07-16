# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/GamepadBindingController.gd
# Description: Infrastructure Controller coordinating input captures, 
#              unhandled joypad events, and synchronizing with the repository.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively input state 
#   coordination, keeping UI script lengths strictly under 50 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GamepadBindingController
extends Node

signal binding_completed(action_name: String, button_index: int)

var _active_bindings: Dictionary = {}
var _listening_action: String = ""


func _ready() -> void:
	name = "GamepadBindingController"
	_active_bindings = GamepadBindingsRepository.load_bindings_dict()


## Starts the listening state for a specific input action.
func start_listening(action_name: String) -> void:
	_listening_action = action_name


## Returns true if the controller is actively waiting for a button press.
func is_listening() -> bool:
	return _listening_action != ""


## Returns the active bindings dictionary cached in memory.
func get_active_bindings() -> Dictionary:
	return _active_bindings


## Restores all customized mappings back to default game parameters.
func reset_to_defaults() -> void:
	_active_bindings = GamepadBindingsRepository._default_bindings.duplicate()
	GamepadBindingsRepository.save_bindings_dict(_active_bindings)
	GamepadBindingsRepository.load_and_apply_bindings()
	binding_completed.emit("", -1)


## Intercepts hardware button presses on the joypad when listening is active.
func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "":
		return
		
	if event is InputEventJoypadButton and event.is_pressed():
		var joy_btn := event as InputEventJoypadButton
		var button_idx := int(joy_btn.button_index)
		
		_apply_new_binding(button_idx)
		get_viewport().set_input_as_handled()


func _apply_new_binding(button_index: int) -> void:
	_active_bindings[_listening_action] = button_index
	GamepadBindingsRepository.save_bindings_dict(_active_bindings)
	GamepadBindingsRepository.load_and_apply_bindings()
	
	var completed_action := _listening_action
	_listening_action = ""
	
	binding_completed.emit(completed_action, button_index)
