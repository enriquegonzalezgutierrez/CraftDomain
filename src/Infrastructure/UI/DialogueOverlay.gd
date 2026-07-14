# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/DialogueOverlay.gd
# Description: Infrastructure Coordinator strictly managing Dialogue Panel data 
#              population and option routing. Layout and styling are defined in .tscn.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
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


func load_dialogue_node(node: Resource, speaker_name: String) -> void:
	var typed_node: DialogueNode = node as DialogueNode
	if typed_node == null: return
		
	AudioService.play_sfx_static("npc_chat")
	_name_label.text = tr(speaker_name).to_upper()
	_text_label.text = tr(typed_node.text)
	
	_clear_choices()
	_populate_choices(typed_node)


func _clear_choices() -> void:
	for child: Node in _choices_container.get_children():
		child.queue_free()


func _populate_choices(node: DialogueNode) -> void:
	if node.choices.size() > 0:
		for choice_res: Resource in node.choices:
			var choice: DialogueChoice = choice_res as DialogueChoice
			if choice != null:
				_choices_container.add_child(_create_choice_button(choice))
	else:
		_choices_container.add_child(_create_fallback_close_button())


func _create_choice_button(choice: DialogueChoice) -> Button:
	var btn: Button = Button.new()
	btn.text = tr(choice.option_text)
	btn.custom_minimum_size = Vector2(0, 34)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	btn.pressed.connect(func() -> void:
		var target: String = choice.target_node_id
		if target != "":
			choice_selected.emit(target)
		else:
			dialogue_closed.emit()
	)
	return btn


func _create_fallback_close_button() -> Button:
	var close_btn: Button = Button.new()
	close_btn.text = tr("DIALOGUE_CONTINUE_CLOSE").to_upper()
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: dialogue_closed.emit())
	return close_btn


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dialogue_closed.emit()
