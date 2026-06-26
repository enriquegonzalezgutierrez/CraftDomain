# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing an interactive, 
#              glassmorphic bottom-docked dialogue overlay with branching options.
#              FIXED: Utilizes loose dynamic Resource casting to completely bypass
#              external class member resolving errors in Godot 4.6.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/DialogueOverlay.gd
# ==============================================================================
class_name DialogueOverlay
extends Panel

## Emitted when the player clicks an option to navigate to a new node.
signal choice_selected(target_node_id: String)

## Emitted when the dialogue sequence ends and closes.
signal dialogue_closed

var _panel_container: Panel
var _name_label: Label
var _text_label: Label
var _choices_container: VBoxContainer

func _ready() -> void:
	# Fullscreen overlay dark transparent wash
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.35) # Dark screen tint
	add_theme_stylebox_override("panel", bg_style)
	
	_setup_dialogue_ui()

func _setup_dialogue_ui() -> void:
	# 1. Glassmorphic Bottom dialogue card container
	_panel_container = Panel.new()
	_panel_container.name = "DialogueCard"
	_panel_container.custom_minimum_size = Vector2(650, 240)
	_panel_container.size = Vector2(650, 240)
	_panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	_panel_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel_container.offset_left = -325
	_panel_container.offset_right = 325
	_panel_container.offset_bottom = -30
	_panel_container.offset_top = -270
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.bg_color = Color(0.06, 0.06, 0.08, 0.85) # Semi-transparent dark slate
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 0.6)
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.4)
	_panel_container.add_theme_stylebox_override("panel", style)
	add_child(_panel_container)
	
	# Margin Layout
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel_container.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)
	
	# 2. Speaker Name Label (Gold color)
	_name_label = Label.new()
	_name_label.name = "SpeakerName"
	_name_label.text = "MERCHANT"
	var name_settings := LabelSettings.new()
	name_settings.font_size = 18
	name_settings.font_color = Color(1.0, 0.85, 0.2)
	name_settings.outline_size = 3
	name_settings.outline_color = Color.BLACK
	_name_label.label_settings = name_settings
	vbox.add_child(_name_label)
	
	vbox.add_child(_create_spacer(6))
	
	# 3. Speaker Speech Text Label
	_text_label = Label.new()
	_text_label.name = "SpeechText"
	_text_label.text = "Hmmm? What can I do for you today, traveler?"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.custom_minimum_size = Vector2(0, 50)
	var text_settings := LabelSettings.new()
	text_settings.font_size = 15
	text_settings.font_color = Color(0.9, 0.95, 1.0)
	_text_label.label_settings = text_settings
	vbox.add_child(_text_label)
	
	vbox.add_child(_create_spacer(14))
	
	# 4. Vertical Choices Button Container
	_choices_container = VBoxContainer.new()
	_choices_container.name = "ChoicesContainer"
	_choices_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_choices_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_choices_container)

## Public API: Displays a specific dialogue node and rebuilds option buttons dynamically.
## FIXED: Receives generic Resource to bypass compile-time class loading races
func load_dialogue_node(node: Resource, speaker_name: String) -> void:
	if not is_instance_valid(node):
		return
		
	# 1. Update text fields
	_name_label.text = speaker_name.to_upper()
	_text_label.text = str(node.get("text"))
	
	# 2. Clear old button instances
	for child in _choices_container.get_children():
		child.queue_free()
		
	# 3. Dynamically populate option buttons extracting values safely
	var choices_list: Array = node.get("choices")
	if choices_list.size() > 0:
		for choice in choices_list:
			var btn := _create_choice_button(choice)
			_choices_container.add_child(btn)
	else:
		# Default fallback close button if no options are present (Leaf node)
		var close_btn := Button.new()
		close_btn.text = "CONTINUE (CLOSE)"
		close_btn.custom_minimum_size = Vector2(0, 38)
		close_btn.pressed.connect(func() -> void: dialogue_closed.emit())
		_choices_container.add_child(close_btn)

## FIXED: Receives generic Resource to bypass compiler locks
func _create_choice_button(choice: Resource) -> Button:
	var btn := Button.new()
	btn.text = str(choice.get("option_text"))
	btn.custom_minimum_size = Vector2(0, 38)
	btn.pivot_offset = Vector2(300, 19) # Pivot offset for scaling from the center
	
	# StyleBox Setup
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.15, 0.7)
	style_normal.set_corner_radius_all(8)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.25, 0.25, 0.3, 0.5)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.18, 0.22, 0.85)
	style_hover.set_corner_radius_all(8)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1.0, 0.85, 0.2, 0.8) # Gold highlight on focus
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 13)
	
	# Connect signals for interactive hovering scaling
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	
	# Choice selection event trigger
	btn.pressed.connect(func() -> void:
		var target: String = str(choice.get("target_node_id"))
		if target != "":
			choice_selected.emit(target)
		else:
			dialogue_closed.emit()
	)
	
	return btn

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
