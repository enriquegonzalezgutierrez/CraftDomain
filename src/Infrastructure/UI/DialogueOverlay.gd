# ==============================================================================
# Pathfile: res://src/Infrastructure/Dialogue/DialogueOverlay.gd
# Description: Infrastructure Coordinator strictly managing Dialogue Panel data 
#              population and option routing. Layout and styling are defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueOverlay
extends Panel

signal choice_selected(target_node_id: String)
signal dialogue_closed

@onready var _name_label: Label = $DialogueCard/MarginContainer/VBoxContainer/SpeakerName
@onready var _text_label: Label = $DialogueCard/MarginContainer/VBoxContainer/SpeechText
@onready var _choices_container: GridContainer = $DialogueCard/MarginContainer/VBoxContainer/ChoicesContainer


## Public API: Displays a specific dialogue node and rebuilds option buttons dynamically.
func load_dialogue_node(node: Resource, speaker_name: String) -> void:
	var typed_node := node as DialogueNode
	if typed_node == null:
		return
		
	AudioService.play_sfx_static("npc_chat")
	_name_label.text = tr(speaker_name).to_upper()
	_text_label.text = tr(typed_node.text)
	
	for child in _choices_container.get_children():
		child.queue_free()
		
	if typed_node.choices.size() > 0:
		for choice_res: Resource in typed_node.choices:
			var choice := choice_res as DialogueChoice
			if choice != null:
				_choices_container.add_child(_create_choice_button(choice))
	else:
		# Default fallback close button if no options are present (Leaf node)
		var close_btn := Button.new()
		close_btn.text = tr("DIALOGUE_CONTINUE_CLOSE").to_upper()
		close_btn.custom_minimum_size = Vector2(0, 34)
		close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_btn.pressed.connect(func() -> void: dialogue_closed.emit())
		_choices_container.add_child(close_btn)


func _create_choice_button(choice: DialogueChoice) -> Button:
	var btn := Button.new()
	btn.text = tr(choice.option_text)
	btn.custom_minimum_size = Vector2(0, 34)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	btn.pressed.connect(func() -> void:
		var target := choice.target_node_id
		if target != "":
			choice_selected.emit(target)
		else:
			dialogue_closed.emit()
	)
	return btn


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dialogue_closed.emit()
