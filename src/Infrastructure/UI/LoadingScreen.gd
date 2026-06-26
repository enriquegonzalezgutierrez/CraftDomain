# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI component representing a standalone Loading Screen.
#              SRP COMPLIANT: Responsible ONLY for rendering, animating progress,
#              and executing fade-out transitions on player spawn.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/LoadingScreen.gd
# ==============================================================================
class_name LoadingScreen
extends Panel

var player: CharacterBody3D

# Inner UI nodes created dynamically
var _spinner: Label
var _status: Label

func _init(p_player: CharacterBody3D) -> void:
	player = p_player
	name = "LoadingScreenOverlay"

func _ready() -> void:
	# Fullscreen overlay dark transparent wash
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 1.0) # Solid background
	add_theme_stylebox_override("panel", style)
	
	_setup_loading_layout()

func _setup_loading_layout() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "CRAFT DOMAIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 46
	ts.font_color = Color(1.0, 0.85, 0.2)
	ts.outline_size = 8
	ts.outline_color = Color.BLACK
	title.label_settings = ts
	vbox.add_child(title)
	
	vbox.add_child(_create_spacer(10))
	
	# Animated status label
	_status = Label.new()
	_status.text = "GENERATING PROCEDURAL WORLD..."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ss := LabelSettings.new()
	ss.font_size = 16
	ss.font_color = Color(0.9, 0.9, 0.95)
	_status.label_settings = ss
	vbox.add_child(_status)
	
	vbox.add_child(_create_spacer(20))
	
	# Programmatic visual spinner
	_spinner = Label.new()
	_spinner.text = "◐"
	_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner.pivot_offset = Vector2(10, 10)
	var sp_style := LabelSettings.new()
	sp_style.font_size = 36
	sp_style.font_color = Color(1.0, 0.85, 0.2)
	_spinner.label_settings = sp_style
	vbox.add_child(_spinner)
	
	vbox.add_child(_create_spacer(45))
	
	# Gameplay hint card
	var tip := Label.new()
	tip.text = "PRO-TIP: Check your compass at the top of the HUD. Walk towards the orange radar pixels to discover village settlements!"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tp := LabelSettings.new()
	tp.font_size = 11
	tp.font_color = Color(0.65, 0.65, 0.7)
	tip.label_settings = tp
	vbox.add_child(tip)

func _process(delta: float) -> void:
	if is_instance_valid(_spinner):
		_spinner.rotation += delta * 6.0
		
	# Cycle the loading status dots dynamically
	if is_instance_valid(_status):
		var elapsed := Time.get_ticks_msec() / 1000.0
		var dot_count := int(floor(elapsed * 2.0)) % 4
		var dots := ""
		for j in range(dot_count):
			dots += "."
		_status.text = "GENERATING PROCEDURAL WORLD" + dots
		
	# DISMISS CHECK: Smoothly fade out when player spawn completes
	if is_instance_valid(player) and player.get("is_active"):
		set_process(false) # Disable update loop
		var fade_tween := create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fade_tween.tween_callback(queue_free)

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
