# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for rendering the 
#              dynamic, color-coded FPS (Frames Per Second) counter.
#              i18n UPGRADE: Uses `tr()` to localize the FPS label text, 
#              ensuring 100% OCP compliance across the UI.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd
# ==============================================================================
class_name FPSCounterWidget
extends Label


func _ready() -> void:
	name = "FPSCounter"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 15
	offset_top = 15
	
	var ls := LabelSettings.new()
	ls.font_size = 18
	ls.font_color = Color(0.2, 1.0, 0.2) # Start with green
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	label_settings = ls


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	
	# Dynamically localized prefix using Godot's translation engine
	text = tr("HUD_FPS") + ": " + str(fps)
	
	# Dynamically color-code the text based on performance thresholds
	if fps >= 55:
		label_settings.font_color = Color(0.2, 1.0, 0.2) # Green (Excellent)
	elif fps >= 30:
		label_settings.font_color = Color(1.0, 0.85, 0.2) # Yellow (Moderate Drop)
	else:
		label_settings.font_color = Color(1.0, 0.2, 0.2) # Red (Lag/Performance Issue)
