# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/LoadingScreen.gd
# Description: Infrastructure UI component representing a standalone Loading Screen.
#              Refactored to support a minimum exposure grace period and 
#              unconditional dynamic gameplay tips randomization on boot.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates loading visual 
#   spins, dot animations, and fading transitions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LoadingScreen
extends Panel

const MIN_EXPOSURE_TIME_SEC: float = 1.2

var player: CharacterBody3D

@onready var _spinner: Label = $CenterContainer/VBoxContainer/Spinner
@onready var _status: Label = $CenterContainer/VBoxContainer/Status
@onready var _tip_label: Label = $CenterContainer/VBoxContainer/Tip

var _elapsed_time: float = 0.0


func _ready() -> void:
	_elapsed_time = 0.0
	_select_random_loading_tip()


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


func _select_random_loading_tip() -> void:
	if not is_instance_valid(_tip_label):
		return
		
	# Symmetrical OCP Catalog: List of translated survival and lore-aligned tips
	var tips_catalog: Array[String] = [
		"LOADING_TIP",          # Original Alt-Mouse tip
		"LOADING_TIP_GLIDER",   # Glider flight tip
		"LOADING_TIP_LAVA",     # Merchant trade tip
		"LOADING_TIP_ZOMBIE",   # Combat knockback tip
		"LOADING_TIP_SCYTHE",   # Chrono-Scythe rift tip
		"LOADING_TIP_SHIELD"    # Coordinated alarm defenders tip
	]
	
	var random_index := randi() % tips_catalog.size()
	_tip_label.text = tr(tips_catalog[random_index])


func _fade_out_and_free() -> void:
	var parent_node := get_parent()
	var fade_tween := create_tween()
	
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	if is_instance_valid(parent_node) and parent_node is CanvasLayer and parent_node.name == "LoadingScreenCanvas":
		fade_tween.tween_callback(parent_node.queue_free)
	else:
		fade_tween.tween_callback(queue_free)
