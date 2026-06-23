# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI component providing a dynamic Settings menu
#              to control Music Volume, SFX Volume, and Display Resolutions.
#              Uses OS feature flags to prevent Editor-embedded window crashes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/SettingsMenu.gd
# ==============================================================================
class_name SettingsMenu
extends Panel

## Emitted when the user clicks the BACK button to close the settings.
signal closed

var _res_opt: OptionButton

func _ready() -> void:
	# Full-screen glassmorphic overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9) # Deep dark blue/grey wash
	add_theme_stylebox_override("panel", style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	# 1. Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_style := LabelSettings.new()
	title_style.font_size = 32
	title_style.font_color = Color(1.0, 0.95, 0.85)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	title.label_settings = title_style
	box.add_child(title)
	
	box.add_child(_create_spacer(30))
	
	# 2. Music Volume Slider
	box.add_child(_create_label("Music Volume"))
	var music_slider := HSlider.new()
	music_slider.min_value = -40.0 # -40 dB is essentially silent
	music_slider.max_value = 0.0   # 0 dB is max original volume
	music_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("Music"))
	music_slider.value_changed.connect(_on_music_changed)
	box.add_child(music_slider)
	
	box.add_child(_create_spacer(15))
	
	# 3. SFX Volume Slider
	box.add_child(_create_label("Effects Volume"))
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -40.0
	sfx_slider.max_value = 0.0
	sfx_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("SFX"))
	sfx_slider.value_changed.connect(_on_sfx_changed)
	box.add_child(sfx_slider)
	
	box.add_child(_create_spacer(25))
	
	# 4. Display Resolution Dropdown
	box.add_child(_create_label("Display Resolution"))
	
	var res_hbox := HBoxContainer.new()
	res_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(res_hbox)
	
	_res_opt = OptionButton.new()
	_res_opt.add_item("Windowed (1280 x 720)", 0)
	_res_opt.add_item("Windowed (1920 x 1080)", 1)
	_res_opt.add_item("Fullscreen", 2)
	_res_opt.custom_minimum_size = Vector2(250, 40)
	
	# Sync dropdown state with current high-level Root Window mode (Safe check)
	if not OS.has_feature("editor"):
		var main_window: Window = get_tree().root
		if main_window.mode == Window.MODE_FULLSCREEN or main_window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			_res_opt.select(2)
		elif main_window.size.x > 1280:
			_res_opt.select(1)
		else:
			_res_opt.select(0)
	res_hbox.add_child(_res_opt)
	
	var apply_btn := Button.new()
	apply_btn.text = "APPLY"
	apply_btn.custom_minimum_size = Vector2(80, 40)
	apply_btn.pressed.connect(_on_apply_resolution_pressed)
	res_hbox.add_child(apply_btn)
	
	box.add_child(_create_spacer(40))
	
	# 5. Back / Close Button
	var close_btn := Button.new()
	close_btn.text = "BACK"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.pressed.connect(func() -> void: closed.emit())
	box.add_child(close_btn)

func _create_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 18
	l.label_settings = ls
	return l

func _create_spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

## Safely locates an Audio Bus by name, or creates it programmatically if it doesn't exist
func _get_or_create_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx

func _on_music_changed(val: float) -> void:
	var bus_idx := _get_or_create_bus("Music")
	AudioServer.set_bus_volume_db(bus_idx, val)
	AudioServer.set_bus_mute(bus_idx, val <= -39.0)

func _on_sfx_changed(val: float) -> void:
	var bus_idx := _get_or_create_bus("SFX")
	AudioServer.set_bus_volume_db(bus_idx, val)
	AudioServer.set_bus_mute(bus_idx, val <= -39.0)

func _on_apply_resolution_pressed() -> void:
	# Safely intercept Godot embedded editor constraints using native OS features
	if OS.has_feature("editor"):
		print("[SettingsMenu] Resolution ignored: Running in Godot Editor debug wrapper. Fullscreen API will work flawlessly in your final exported game!")
		return
		
	var idx := _res_opt.get_selected_id()
	var main_window: Window = get_tree().root
	
	# Apply resolution to the native OS window
	match idx:
		0:
			main_window.mode = Window.MODE_WINDOWED
			main_window.size = Vector2i(1280, 720)
			main_window.move_to_center()
		1:
			main_window.mode = Window.MODE_WINDOWED
			main_window.size = Vector2i(1920, 1080)
			main_window.move_to_center()
		2:
			main_window.mode = Window.MODE_FULLSCREEN
