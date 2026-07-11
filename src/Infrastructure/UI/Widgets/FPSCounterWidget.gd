# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd
# Description: SRP-compliant UI Widget responsible ONLY for updating the 
#              dynamic FPS text and color-coding based on performance.
#              Layout and base visual properties are defined in the .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FPSCounterWidget
extends Label


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	
	# Dynamically localized prefix using Godot's translation engine
	text = tr("HUD_FPS") + ": " + str(fps)
	
	if label_settings != null:
		# Dynamically color-code the text based on performance thresholds
		if fps >= 55:
			label_settings.font_color = Color(0.2, 1.0, 0.2) # Green (Excellent)
		elif fps >= 30:
			label_settings.font_color = Color(1.0, 0.85, 0.2) # Yellow (Moderate Drop)
		else:
			label_settings.font_color = Color(1.0, 0.2, 0.2) # Red (Lag/Performance Issue)
