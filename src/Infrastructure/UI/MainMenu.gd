# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing the main menu overlay.
#              UX IMPROVED: Added premium glassmorphic button styling, tactile 
#              hover scale animations, and a floating sine-wave game title.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MainMenu.gd
# ==============================================================================
class_name MainMenu
extends Control

## Emitted when the player clicks the "Play World" button.
signal play_pressed

var _settings_overlay: Control
var _title_label: Label
var _time_passed: float = 0.0

func _ready() -> void:
	# Stretch the root control node to fill the entire window viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Background texture
	var bg := TextureRect.new()
	bg.name = "MenuBackground"
	bg.texture = load("res://src/Infrastructure/UI/Assets/menu_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Dark translucent wash to make text readable over the background
	var wash := ColorRect.new()
	wash.name = "ColorWash"
	wash.color = Color(0.05, 0.05, 0.08, 0.6) # Darker, richer wash for contrast
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	
	# 3. UI centering container
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(box)
	
	# 4. Game Title with Premium Styling
	_title_label = Label.new()
	_title_label.name = "GameTitle"
	_title_label.text = "CRAFT DOMAIN"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings := LabelSettings.new()
	settings.font_size = 64
	settings.font_color = Color(1.0, 0.95, 0.85) # Soft cream white
	settings.outline_size = 12
	settings.outline_color = Color(0.08, 0.08, 0.08) # Dark contrast border
	settings.shadow_size = 8
	settings.shadow_color = Color(0, 0, 0, 0.5)
	settings.shadow_offset = Vector2(0, 5)
	_title_label.label_settings = settings
	
	# Wrap title in a Control to allow vertical offset animation without breaking VBox spacing
	var title_wrapper := Control.new()
	title_wrapper.custom_minimum_size = Vector2(500, 100)
	title_wrapper.add_child(_title_label)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_child(title_wrapper)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	
	# 5. Create Premium Buttons
	var play_btn := _create_premium_button("PLAY WORLD")
	play_btn.pressed.connect(_on_play_pressed)
	box.add_child(play_btn)
	
	box.add_child(_create_spacer(15))
	
	var settings_btn := _create_premium_button("SETTINGS")
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	box.add_child(_create_spacer(15))
	
	var exit_btn := _create_premium_button("EXIT GAME")
	exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(exit_btn)

func _process(delta: float) -> void:
	# Subtle floating animation for the Game Title
	if is_instance_valid(_title_label):
		_time_passed += delta * 2.0
		# Oscillate vertically by +/- 8 pixels
		_title_label.position.y = sin(_time_passed) * 8.0

## Factory method to programmatically construct highly polished glassmorphic buttons
func _create_premium_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 55)
	
	# Move pivot to center so the hover scale animation grows outward naturally
	btn.pivot_offset = Vector2(140, 27.5)
	
	# Normal State Style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.12, 0.7)
	style_normal.set_corner_radius_all(12)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.35, 0.8)
	style_normal.shadow_size = 4
	style_normal.shadow_color = Color(0, 0, 0, 0.3)
	
	# Hover State Style (Brighter with Golden Border)
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.85)
	style_hover.set_corner_radius_all(12)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1.0, 0.85, 0.2, 1.0) # Golden glow
	style_hover.shadow_size = 8
	style_hover.shadow_color = Color(0, 0, 0, 0.5)
	
	# Pressed State Style
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	
	# Apply themes
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new()) # Remove ugly dotted outline
	
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	
	# Add tactile scaling animations via signals
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	
	return btn

func _create_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _on_play_pressed() -> void:
	play_pressed.emit()

func _on_settings_pressed() -> void:
	# Load settings menu component via script injection for safe reference
	var sm_script: Script = load("res://src/Infrastructure/UI/SettingsMenu.gd")
	if sm_script != null:
		_settings_overlay = sm_script.new() as Control
		_settings_overlay.connect("closed", Callable(self, "_on_settings_closed"))
		add_child(_settings_overlay)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
