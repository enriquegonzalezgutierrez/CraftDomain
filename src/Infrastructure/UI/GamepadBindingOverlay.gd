# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/GamepadBindingOverlay.gd
# Description: Tactile Glassmorphic Overlay for customization of gamepad buttons.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively UI signals 
#   and label animations, keeping script length strictly under 50 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GamepadBindingOverlay
extends Panel

signal closed

@onready var _controller: GamepadBindingController = $GamepadBindingController
@onready var _close_button: Button = $Card/VBox/CloseButton
@onready var _reset_button: Button = $Card/VBox/ResetButton

# Declarative button links mapped in the .tscn structure
@onready var _buttons: Dictionary = {
	"jump": $Card/VBox/Grid/JumpButton,
	"click_left": $Card/VBox/Grid/AttackButton,
	"click_right": $Card/VBox/Grid/InteractButton,
	"toggle_backpack": $Card/VBox/Grid/InventoryButton,
	"craft_item": $Card/VBox/Grid/CraftButton,
	"toggle_world_map": $Card/VBox/Grid/MapButton,
	"ui_cancel": $Card/VBox/Grid/PauseButton
}


func _ready() -> void:
	_close_button.pressed.connect(func() -> void: closed.emit())
	_reset_button.pressed.connect(_controller.reset_to_defaults)
	_controller.binding_completed.connect(_on_binding_completed)
	
	for action_name: String in _buttons.keys():
		var btn: Button = _buttons[action_name]
		btn.pressed.connect(_on_binding_button_pressed.bind(action_name))
		
	_refresh_ui_labels()


func _on_binding_button_pressed(action_name: String) -> void:
	if _controller.is_listening():
		return
	_controller.start_listening(action_name)
	_buttons[action_name].text = tr("BUTTON_PAD_LISTENING").to_upper()
	AudioService.play_sfx_static("ui_click")


func _on_binding_completed(_action_name: String, _button_index: int) -> void:
	_refresh_ui_labels()
	AudioService.play_sfx_static("loot_pickup")


func _refresh_ui_labels() -> void:
	var active_bindings := _controller.get_active_bindings()
	for action_name: String in _buttons.keys():
		var btn: Button = _buttons[action_name]
		var btn_index: int = active_bindings[action_name] as int
		btn.text = tr(GamepadBindingsRepository.get_button_name_localized(btn_index)).to_upper()
