# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/LoadingScreen.gd
# Description: Infrastructure UI component representing a standalone Loading Screen.
#              Refactored to support a minimum exposure grace period, allowing
#              gameplay tips and entry animations to display smoothly even under
#              sub-millisecond chunk generation speeds.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates loading visual 
#   spins, dot animations, and fading transitions. All methods kept strictly < 20 lines.
# - 120 FPS Guardrail: Physics processes are safely deactivated on fade-out to 
#   avoid redundant draw calls.
# - UX Optimization: Checked parent container type during fadeout to safely free 
#   the top-level CanvasLayer container once the panel opacity has faded.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LoadingScreen
extends Panel

const MIN_EXPOSURE_TIME_SEC: float = 1.2

var player: CharacterBody3D

@onready var _spinner: Label = $CenterContainer/VBoxContainer/Spinner
@onready var _status: Label = $CenterContainer/VBoxContainer/Status

var _elapsed_time: float = 0.0


func _ready() -> void:
	_elapsed_time = 0.0


func _process(delta: float) -> void:
	_elapsed_time += delta
	_animate_spinner(delta)
	_animate_status_dots()
	_check_dismiss_condition()


func _animate_spinner(delta: float) -> void:
	if is_instance_valid(_spinner):
		_spinner.rotation += delta * 6.0


func _animate_status_dots() -> void:
	if is_instance_valid(_status):
		var elapsed := Time.get_ticks_msec() / 1000.0
		var dot_count := int(floor(elapsed * 2.0)) % 4
		var dots := ""
		for j: int in range(dot_count):
			dots += "."
		_status.text = tr("LOADING_STATUS").to_upper() + dots


func _check_dismiss_condition() -> void:
	var player_ready := is_instance_valid(player) and player.get("is_active") as bool
	var exposure_completed := _elapsed_time >= MIN_EXPOSURE_TIME_SEC
	
	if player_ready and exposure_completed:
		set_process(false)
		_fade_out_and_free()


func _fade_out_and_free() -> void:
	var parent_node := get_parent()
	var fade_tween := create_tween()
	
	# Always fade out this LoadingScreen Panel itself (Control node guarantees 'modulate:a' validity)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	# Determine what needs to be freed at the end of the fade animation
	if is_instance_valid(parent_node) and parent_node is CanvasLayer and parent_node.name == "LoadingScreenCanvas":
		fade_tween.tween_callback(parent_node.queue_free)
	else:
		fade_tween.tween_callback(queue_free)
