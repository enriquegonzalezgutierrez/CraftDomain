# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing the main menu overlay,
#              building containers, text styling, and custom buttons programmatically.
#              Ensures full-screen viewport scaling and perfect alignment.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MainMenu.gd
# ==============================================================================
class_name MainMenu
extends Control

## Emitted when the player clicks the "Play World" button.
signal play_pressed

func _ready() -> void:
	# Stretch the root control node to fill the entire window viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Background texture using the AI generated image
	var bg := TextureRect.new()
	bg.name = "MenuBackground"
	bg.texture = load("res://src/Infrastructure/UI/Assets/menu_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Dark translucent wash to make text readable over the background
	var wash := ColorRect.new()
	wash.name = "ColorWash"
	wash.color = Color(0, 0, 0, 0.35)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	
	# 3. UI centering container
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	var box := VBoxContainer.new()
	center_container.add_child(box)
	
	# 4. Game Title
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "CRAFT DOMAIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Custom text styling built programmatically
	var settings := LabelSettings.new()
	settings.font_size = 56
	settings.font_color = Color(1.0, 0.95, 0.85) # Soft cream white
	settings.outline_size = 8
	settings.outline_color = Color(0.12, 0.12, 0.12) # Dark contrast border
	title.label_settings = settings
	box.add_child(title)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)
	
	# 5. Play Button
	var play_btn := Button.new()
	play_btn.name = "PlayButton"
	play_btn.text = "PLAY WORLD"
	play_btn.custom_minimum_size = Vector2(250, 48)
	play_btn.pressed.connect(_on_play_pressed)
	box.add_child(play_btn)
	
	# Spacer 2
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer2)
	
	# 6. Exit Button
	var exit_btn := Button.new()
	exit_btn.name = "ExitButton"
	exit_btn.text = "EXIT GAME"
	exit_btn.custom_minimum_size = Vector2(250, 48)
	exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(exit_btn)

func _on_play_pressed() -> void:
	play_pressed.emit()

func _on_exit_pressed() -> void:
	get_tree().quit()
