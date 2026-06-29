# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for building and managing 
#              the Pause Menu overlay and its button interactions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/PauseMenuWidget.gd
# ==============================================================================
class_name PauseMenuWidget
extends Panel

var hud_orchestrator: PlayerHUD
var _settings_overlay: SettingsMenu

func _ready() -> void:
	name = "PauseMenuWidget"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	add_theme_stylebox_override("panel", bg_style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	var title := Label.new()
	title.text = tr("HUD_PAUSE_TITLE") # Localized
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var title_style := LabelSettings.new()
	title_style.font_size = 32
	title_style.font_color = Color(1.0, 0.95, 0.85)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	title.label_settings = title_style
	box.add_child(title)
	
	box.add_child(_create_spacer(30))
	
	var resume_btn := _create_menu_button(tr("HUD_PAUSE_RESUME"))
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)
	
	box.add_child(_create_spacer(12))
	
	var settings_btn := _create_menu_button(tr("HUD_PAUSE_SETTINGS"))
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	box.add_child(_create_spacer(12))
	
	var quit_btn := _create_menu_button(tr("HUD_PAUSE_QUIT"))
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)

	visible = false

func _create_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 48)
	
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	sn.set_corner_radius_all(10)
	sn.border_width_left = 1
	sn.border_width_top = 1
	sn.border_width_right = 1
	sn.border_width_bottom = 1
	sn.border_color = Color(0.25, 0.25, 0.3, 0.3)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 14)
	
	return btn

func toggle_menu(p_visible: bool) -> void:
	var tween := create_tween().set_parallel(true)
	
	if p_visible:
		visible = true
		modulate.a = 0.0
		scale = Vector2(0.96, 0.96)
		pivot_offset = get_viewport_rect().size / 2.0
		
		tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		tween.chain().tween_callback(func() -> void:
			visible = false
			if is_instance_valid(_settings_overlay):
				_settings_overlay.queue_free()
		)

func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toggle_menu(false)

func _on_settings_pressed() -> void:
	_settings_overlay = SettingsMenu.new()
	_settings_overlay.closed.connect(_on_settings_closed)
	add_child(_settings_overlay)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_quit_pressed() -> void:
	var bootstrap = get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
