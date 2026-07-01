# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI component providing a dynamic Settings menu
#              to control Music Volume, SFX Volume, Render Distance, and Display 
#              Resolutions.
#              SOLID COMPLIANCE: Adheres to SRP by managing configuration UI.
#              REACTIVITY: Implements safe checks to prevent early SceneTree Null crashes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/SettingsMenu.gd
# ==============================================================================
class_name SettingsMenu
extends Panel

## Emitted when the user clicks the BACK button to close the settings.
signal closed

# Dynamic UI elements cached for localization refreshes (SRP)
var _title_label: Label
var _music_label: Label
var _sfx_label: Label
var _render_dist_label: Label
var _res_label: Label
var _lang_label: Label

var _res_opt: OptionButton
var _lang_opt: OptionButton
var _apply_btn: Button
var _back_btn: Button

func _ready() -> void:
	# Full-screen glassmorphic overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95) # Deep dark blue/grey wash
	add_theme_stylebox_override("panel", style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	# 1. Main Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_style := LabelSettings.new()
	title_style.font_size = 32
	title_style.font_color = Color(1.0, 0.95, 0.85)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	_title_label.label_settings = title_style
	box.add_child(_title_label)
	
	box.add_child(_create_spacer(20))
	
	# 2. Music Volume Slider
	_music_label = _create_label()
	box.add_child(_music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = -40.0 
	music_slider.max_value = 0.0   
	music_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("Music"))
	music_slider.value_changed.connect(_on_music_changed)
	box.add_child(music_slider)
	
	box.add_child(_create_spacer(15))
	
	# 3. SFX Volume Slider
	_sfx_label = _create_label()
	box.add_child(_sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -40.0
	sfx_slider.max_value = 0.0
	sfx_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("SFX"))
	sfx_slider.value_changed.connect(_on_sfx_changed)
	box.add_child(sfx_slider)
	
	box.add_child(_create_spacer(15))
	
	# 4. Render Distance Slider
	_render_dist_label = _create_label()
	box.add_child(_render_dist_label)
	var dist_slider := HSlider.new()
	dist_slider.min_value = 4.0
	dist_slider.max_value = 14.0
	dist_slider.step = 1.0
	dist_slider.value = float(ChunkLoaderService.global_view_distance)
	dist_slider.value_changed.connect(_on_render_distance_changed)
	box.add_child(dist_slider)
	
	box.add_child(_create_spacer(15))
	
	# 5. Display Resolution Dropdown
	_res_label = _create_label()
	box.add_child(_res_label)
	
	var res_hbox := HBoxContainer.new()
	res_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(res_hbox)
	
	_res_opt = OptionButton.new()
	_res_opt.custom_minimum_size = Vector2(250, 40)
	res_hbox.add_child(_res_opt)
	
	_apply_btn = Button.new()
	_apply_btn.custom_minimum_size = Vector2(80, 40)
	_apply_btn.pressed.connect(_on_apply_resolution_pressed)
	res_hbox.add_child(_apply_btn)
	
	box.add_child(_create_spacer(15))
	
	# 6. Interface Language Selector
	_lang_label = _create_label()
	box.add_child(_lang_label)
	
	_lang_opt = OptionButton.new()
	_lang_opt.custom_minimum_size = Vector2(340, 40)
	_lang_opt.add_item("English", 0)
	_lang_opt.add_item("Español", 1)
	
	# Check and select current active language
	var current_locale := TranslationServer.get_locale()
	if current_locale.begins_with("es"):
		_lang_opt.select(1)
	else:
		_lang_opt.select(0)
		
	_lang_opt.item_selected.connect(_on_language_changed)
	box.add_child(_lang_opt)
	
	box.add_child(_create_spacer(30))
	
	# 7. Back / Close Button
	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(0, 48)
	_back_btn.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back_btn)
	
	# 8. Render dynamic localized texts
	_refresh_localized_text()
	_setup_resolution_dropdown_state()


## REACTIVITY: Captures dynamic i18n locale changes from Godot's Translation Server on-the-fly
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


## Dynamically refreshes all visible text elements with the active translation database
func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): _title_label.text = tr("SETTINGS_TITLE")
	if is_instance_valid(_music_label): _music_label.text = tr("SETTINGS_MUSIC")
	if is_instance_valid(_sfx_label): _sfx_label.text = tr("SETTINGS_SFX")
	
	# Render Distance updates with real-time parameter tracking
	if is_instance_valid(_render_dist_label): 
		_render_dist_label.text = tr("SETTINGS_RENDER_DISTANCE") + ": " + str(ChunkLoaderService.global_view_distance)
		
	if is_instance_valid(_res_label): _res_label.text = tr("SETTINGS_RESOLUTION")
	if is_instance_valid(_lang_label): _lang_label.text = tr("SETTINGS_LANGUAGE")
	if is_instance_valid(_back_btn): _back_btn.text = tr("SETTINGS_BACK")
	if is_instance_valid(_apply_btn): _apply_btn.text = tr("SETTINGS_APPLY")
	
	# Redraw resolution drop-down items cleanly with active language (SRP)
	if is_instance_valid(_res_opt):
		var active_index := _res_opt.selected
		_res_opt.clear()
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_720"), 0)
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_1080"), 1)
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_FULLSCREEN"), 2)
		_res_opt.select(active_index)


func _setup_resolution_dropdown_state() -> void:
	if not OS.has_feature("editor"):
		var main_window: Window = get_tree().root
		if main_window.mode == Window.MODE_FULLSCREEN or main_window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			if is_instance_valid(_res_opt): _res_opt.select(2)
		elif main_window.size.x > 1280:
			if is_instance_valid(_res_opt): _res_opt.select(1)
		else:
			if is_instance_valid(_res_opt): _res_opt.select(0)
	else:
		if is_instance_valid(_res_opt):
			_res_opt.select(0)


func _create_label() -> Label:
	var l := Label.new()
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


func _on_render_distance_changed(val: float) -> void:
	ChunkLoaderService.global_view_distance = int(val)
	_refresh_localized_text() # Re-render label to show the new number instantly


func _on_apply_resolution_pressed() -> void:
	if OS.has_feature("editor"):
		print("[SettingsMenu] Resolution ignored inside Godot Editor debug wrapper.")
		return
		
	var idx := _res_opt.get_selected_id()
	var main_window: Window = get_tree().root
	
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


## Triggered when the user picks English or Spanish in the language dropdown
func _on_language_changed(index: int) -> void:
	if index == 0:
		TranslationServer.set_locale("en")
		print("[SettingsMenu] Language changed to English (en).")
	elif index == 1:
		TranslationServer.set_locale("es")
		print("[SettingsMenu] Idioma cambiado a Español (es).")
