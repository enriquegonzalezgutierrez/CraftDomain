# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/SpeechBubble.gd
# Description: Infrastructure UI service managing the 3D Billboard Speech Bubble.
#              SOLID COMPLIANCE:
#              - Rule 7.1 (Declarative UI): Purged procedural node and StyleBox 
#                creation. Delegates visual setup entirely to the .tscn scene.
#              - Single Responsibility Principle (SRP): Handles strictly text updates.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SpeechBubble
extends Node3D

@onready var _label: Label = $SubViewport/BubblePanel/BubbleLabel


func _ready() -> void:
	# Visuals are now automatically managed by the declarative .tscn
	pass


## Public API: Allows dynamic updating of floating dialogue or alerts from outside
func set_text(new_text: String) -> void:
	if is_instance_valid(_label):
		_label.text = new_text.to_upper()
