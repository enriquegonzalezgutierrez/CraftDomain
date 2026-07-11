# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/LoadingScreen.gd
# Description: Infrastructure UI component representing a standalone Loading Screen.
#              Refactored to strictly handle state and animations, delegating
#              layout and styling to its corresponding .tscn scene file.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LoadingScreen
extends Panel

var player: CharacterBody3D

@onready var _spinner: Label = $CenterContainer/VBoxContainer/Spinner
@onready var _status: Label = $CenterContainer/VBoxContainer/Status


func _process(delta: float) -> void:
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
	if is_instance_valid(player) and player.get("is_active") as bool:
		set_process(false)
		var fade_tween := create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fade_tween.tween_callback(queue_free)
