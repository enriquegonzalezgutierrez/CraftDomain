# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI service that programmatically constructs a 
#              3D Billboard Speech Bubble floating above NPC heads.
#              Uses an isolated SubViewport and a Sprite3D to render crisp 2D 
#              Label elements cleanly in 3D space.
#              MEMORY SECURITY FIX: Replaced infinite process_frame lambda with 
#              a native CONNECT_ONE_SHOT method callback to prevent memory leaks on exit.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/SpeechBubble.gd
# ==============================================================================
class_name SpeechBubble
extends Node3D

var _sprite: Sprite3D
var _viewport: SubViewport
var _panel: Panel
var _label: Label

func _ready() -> void:
	_setup_speech_bubble()

## Programmatically builds the viewport texture and Sprite3D billboard projection
func _setup_speech_bubble() -> void:
	# 1. Create a dynamic SubViewport
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(250, 50) # Compact bubble dimension
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	
	# 2. Create glassmorphic backdrop panel
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75) # Dark transparent slate
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	_panel.add_theme_stylebox_override("panel", style)
	_viewport.add_child(_panel)
	
	# 3. Create centered Text Label
	_label = Label.new()
	_label.text = "◐ CLICK TO TRADE!"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var text_settings := LabelSettings.new()
	text_settings.font_size = 14
	text_settings.font_color = Color(1.0, 0.85, 0.2) # Gold
	text_settings.outline_size = 3
	text_settings.outline_color = Color.BLACK
	_label.label_settings = text_settings
	_panel.add_child(_label)
	
	# 4. Create Sprite3D to project the Viewport texture into 3D space
	_sprite = Sprite3D.new()
	_sprite.name = "BillboardSprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Rotates to face the camera
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Sharp pixel texture
	_sprite.pixel_size = 0.008 # Custom scaling in the 3D grid
	
	# Hover exactly at Y=1.9 meters (right above human-npc eye level)
	_sprite.position = Vector3(0, 1.9, 0)
	add_child(_sprite)
	
	# MEMORY FIX: Bind texture dynamically using a safe, one-shot native method
	get_tree().process_frame.connect(_apply_texture, CONNECT_ONE_SHOT)

func _apply_texture() -> void:
	if is_instance_valid(_sprite) and is_instance_valid(_viewport):
		_sprite.texture = _viewport.get_texture()

## Public API: Allows dynamic updating of floating dialogue or alerts from outside
func set_text(new_text: String) -> void:
	if is_instance_valid(_label):
		_label.text = new_text.to_upper()
