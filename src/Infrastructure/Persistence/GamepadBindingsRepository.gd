# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/GamepadBindingsRepository.gd
# Description: Infrastructure Repository managing the persistence, serialization, 
#              and runtime application of custom gamepad/joypad button bindings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively input action 
#   persistence and InputMap hardware alterations.
# - Open-Closed Principle (OCP): Decoupled from core settings menu. Operates on 
#   its own file stream, closing existing files to changes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GamepadBindingsRepository
extends RefCounted

const BINDINGS_FILE_PATH: String = "user://gamepad_bindings.json"

# Abstract representation of customizable gameplay actions
static var _default_bindings: Dictionary = {
	"jump": JOY_BUTTON_A,                  # Xbox A / PS Cross (Jump)
	"click_left": JOY_BUTTON_RIGHT_SHOULDER, # Right Bumper (Mine/Attack)
	"click_right": JOY_BUTTON_LEFT_SHOULDER,  # Left Bumper (Build/Interact)
	"toggle_backpack": JOY_BUTTON_X,        # Xbox X / PS Square (Inventory)
	"craft_item": JOY_BUTTON_Y,             # Xbox Y / PS Triangle (Crafting)
	"toggle_world_map": JOY_BUTTON_BACK,    # Back / Share Button (World Map)
	"ui_cancel": JOY_BUTTON_START           # Start / Options (Pause Menu)
}


## Loads and applies the configured custom joypad button bindings to Godot's InputMap.
## DIP Compliance: Runs synchronously on startup without knowing UI panel states.
static func load_and_apply_bindings() -> void:
	var active_bindings := load_bindings_dict()
	_apply_bindings_to_input_map(active_bindings)


## Reads the custom bindings from the JSON file on disk, falling back to defaults if missing.
static func load_bindings_dict() -> Dictionary:
	if not FileAccess.file_exists(BINDINGS_FILE_PATH):
		return _default_bindings.duplicate()
		
	var file := FileAccess.open(BINDINGS_FILE_PATH, FileAccess.READ)
	if file == null:
		return _default_bindings.duplicate()
		
	var json_string := file.get_as_text()
	file.close()
	
	return _parse_bindings_json(json_string)


## Serializes and writes the custom bindings dictionary back to the secure user directory.
static func save_bindings_dict(bindings: Dictionary) -> void:
	var file := FileAccess.open(BINDINGS_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify(bindings))
		file.close()


## Returns a clean, user-friendly, and localized representation of a JoyButton.
static func get_button_name_localized(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "BUTTON_PAD_A"
		JOY_BUTTON_B: return "BUTTON_PAD_B"
		JOY_BUTTON_X: return "BUTTON_PAD_X"
		JOY_BUTTON_Y: return "BUTTON_PAD_Y"
		JOY_BUTTON_BACK: return "BUTTON_PAD_BACK"
		JOY_BUTTON_START: return "BUTTON_PAD_START"
		JOY_BUTTON_LEFT_SHOULDER: return "BUTTON_PAD_L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "BUTTON_PAD_R1"
		_: return "BUTTON_PAD_UNKNOWN"


static func _parse_bindings_json(json_string: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[GamepadBindingsRepository] JSON parse error: " + json.get_error_message())
		return _default_bindings.duplicate()
		
	var data := json.data as Dictionary
	var parsed: Dictionary = {}
	
	# Validate keys against expected actions to prevent corrupted file injections
	for action_name: String in _default_bindings.keys():
		if data.has(action_name):
			parsed[action_name] = int(data[action_name])
		else:
			parsed[action_name] = _default_bindings[action_name]
			
	return parsed


static func _apply_bindings_to_input_map(bindings: Dictionary) -> void:
	for action_name: String in bindings.keys():
		if not InputMap.has_action(action_name):
			continue
			
		_clear_joypad_button_events(action_name)
		_register_new_joypad_button_event(action_name, int(bindings[action_name]))


static func _clear_joypad_button_events(action_name: String) -> void:
	var events := InputMap.action_get_events(action_name)
	for event: InputEvent in events:
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action_name, event)


static func _register_new_joypad_button_event(action_name: String, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index as JoyButton
	InputMap.action_add_event(action_name, event)
