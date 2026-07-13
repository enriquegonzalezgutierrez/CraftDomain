# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/VirtualControllerWidget.gd
# Description: Platform-aware virtual touchscreen overlay containing joysticks
#              for mobile inputs. Hidden completely on PC platforms (Section 7.1).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VirtualControllerWidget
extends Control

@export var player: CharacterBody3D


func _ready() -> void:
	_evaluate_platform_visibility()


## Evaluates active hardware layers to determine touch controls deployment.
func _evaluate_platform_visibility() -> void:
	# Detect if compiling under Android/iOS or display supports touch coordinates (DIP)
	var is_mobile_platform := OS.has_feature("mobile")
	var is_touch_hardware_available := DisplayServer.is_touchscreen_available()
	
	# STRICT PC PROTECTION: Purge from RAM instantly on desktop, saving memory
	if not is_mobile_platform and not is_touch_hardware_available:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		queue_free()
		return
		
	visible = true
	print("[VirtualController] Touchscreen hardware detected. Initializing overlay...")
