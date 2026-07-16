# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/SettingsMenu.gd
# Description: Infrastructure UI component strictly managing system settings modifications,
#              dynamic localizations, and persistence.
# SOLID COMPLIANCE: Class limits set < 300 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 20 lines.
# - Open-Closed Principle (OCP): Integrates the custom Gamepad Binding Overlay 
#   via runtime instantiation without changing core settings repositories.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SettingsMenu
extends Panel

signal closed

const BINDING_OVERLAY_SCENE := preload("res://src/Infrastructure/UI/gamepad_binding_overlay.tscn")

@onready var _menu_card: Panel = $CenterContainer/MenuCard

@onready var _title_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/TitleLabel
@onready var _music_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/MusicLabel
@onready var _sfx_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/SFXLabel
@onready var _render_dist_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/RenderDistLabel
@onready var _res_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/ResLabel
@onready var _lang_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/LangLabel
@onready var _name_label: Label = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/NameLabel

@onready var _music_slider: HSlider = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/MusicSlider
@onready var _sfx_slider: HSlider = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/SFXSlider
@onready var _dist_slider: HSlider = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/DistSlider

@onready var _res_opt: OptionButton = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/ResHBox/ResOptionButton
@onready var _lang_opt: OptionButton = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/LangOptionButton
@onready var _name_edit: LineEdit = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/NameEdit

@onready var _gamepad_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/GamepadButton
@onready var _apply_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/ResHBox/ApplyButton
@onready var _back_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	_music_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("Music"))
	_sfx_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("SFX"))
	_dist_slider.value = float(ChunkLoaderService.global_view_distance)
	
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_dist_slider.value_changed.connect(_on_render_distance_changed)
	
	_gamepad_btn.pressed.connect(_on_gamepad_bindings_pressed)
	_apply_btn.pressed.connect(_on_apply_resolution_pressed)
	_lang_opt.item_selected.connect(_on_language_changed)
	
	_back_btn.pressed.connect(func() -> void: 
		_save_all_current_settings()
		_play_exit_animation()
	)
	
	_populate_dropdown_items()
	_setup_language_selection_state()
	_setup_resolution_dropdown_state()
	_setup_username_display_state()
	
	_refresh_localized_text()
	_play_entry_animation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


func _populate_dropdown_items() -> void:
	if is_instance_valid(_lang_opt):
		_lang_opt.clear()
		_lang_opt.add_item("ENGLISH", 0)
		_lang_opt.add_item("ESPAÑOL", 1)
		
	if is_instance_valid(_res_opt):
		_res_opt.clear()
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_720"), 0)
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_1080"), 1)
		_res_opt.add_item(tr("SETTINGS_RESOLUTION_FULLSCREEN"), 2)


func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): _title_label.text = tr("SETTINGS_TITLE").to_upper()
	if is_instance_valid(_music_label): _music_label.text = tr("SETTINGS_MUSIC")
	if is_instance_valid(_sfx_label): _sfx_label.text = tr("SETTINGS_SFX")
	
	_text_slider_val_update()
		
	if is_instance_valid(_res_label): _res_label.text = tr("SETTINGS_RESOLUTION")
	if is_instance_valid(_lang_label): _lang_label.text = tr("SETTINGS_LANGUAGE")
	if is_instance_valid(_name_label): _name_label.text = tr("SETTINGS_USERNAME")
	if is_instance_valid(_gamepad_btn): _gamepad_btn.text = tr("SETTINGS_GAMEPAD_BINDINGS").to_upper()
	if is_instance_valid(_back_btn): _back_btn.text = tr("SETTINGS_BACK").to_upper()
	if is_instance_valid(_apply_btn): _apply_btn.text = tr("SETTINGS_APPLY").to_upper()
	
	if is_instance_valid(_res_opt):
		var active_index: int = _res_opt.selected
		_res_opt.set_item_text(0, tr("SETTINGS_RESOLUTION_720"))
		_res_opt.set_item_text(1, tr("SETTINGS_RESOLUTION_1080"))
		_res_opt.set_item_text(2, tr("SETTINGS_RESOLUTION_FULLSCREEN"))
		_res_opt.select(active_index)


func _setup_language_selection_state() -> void:
	var current_locale: String = TranslationServer.get_locale()
	if current_locale.begins_with("es"):
		_lang_opt.select(1)
	else:
		_lang_opt.select(0)


func _setup_resolution_dropdown_state() -> void:
	if not OS.has_feature("editor"):
		var main_window: Window = get_tree().root
		if main_window.mode == Window.MODE_FULLSCREEN or main_window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			_res_opt.select(2)
		elif main_window.size.x > 1280:
			_res_opt.select(1)
		else:
			_res_opt.select(0)
	else:
		_res_opt.select(0)


func _setup_username_display_state() -> void:
	if not is_instance_valid(_name_edit):
		return
		
	var settings := SettingsRepository.load_settings()
	if settings.has("username") and str(settings["username"]).strip_edges() != "":
		_name_edit.text = str(settings["username"]).strip_edges()
	else:
		var os_user := OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else OS.get_environment("USER")
		_name_edit.text = os_user if os_user != "" else "Player"


func _play_entry_animation() -> void:
	modulate.a = 0.0
	_menu_card.scale = Vector2(0.95, 0.95)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_exit_animation() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_menu_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: closed.emit())


func _on_music_changed(val: float) -> void:
	var bus_idx: int = _get_or_create_bus("Music")
	AudioServer.set_bus_volume_db(bus_idx, val)
	AudioServer.set_bus_mute(bus_idx, val <= -39.0)


func _on_sfx_changed(val: float) -> void:
	var bus_idx: int = _get_or_create_bus("SFX")
	AudioServer.set_bus_volume_db(bus_idx, val)
	AudioServer.set_bus_mute(bus_idx, val <= -39.0)


func _on_render_distance_changed(val: float) -> void:
	ChunkLoaderService.global_view_distance = int(val)
	_text_slider_val_update()


func _text_slider_val_update() -> void:
	if is_instance_valid(_render_dist_label):
		_render_dist_label.text = tr("SETTINGS_RENDER_DISTANCE") + ": " + str(ChunkLoaderService.global_view_distance)


func _on_apply_resolution_pressed() -> void:
	if OS.has_feature("editor"):
		return
		
	var idx: int = _res_opt.get_selected_id()
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
			
	_save_all_current_settings()


func _on_language_changed(index: int) -> void:
	if index == 0:
		TranslationServer.set_locale("en")
	elif index == 1:
		TranslationServer.set_locale("es")
		
	_save_all_current_settings()


func _on_gamepad_bindings_pressed() -> void:
	var overlay := BINDING_OVERLAY_SCENE.instantiate() as GamepadBindingOverlay
	add_child(overlay)
	overlay.closed.connect(func() -> void:
		overlay.queue_free()
	)
	AudioService.play_sfx_static("ui_click")


func _save_all_current_settings() -> void:
	var music_val: float = _music_slider.value if is_instance_valid(_music_slider) else -6.0
	var sfx_val: float = _sfx_slider.value if is_instance_valid(_sfx_slider) else -6.0
	var render_dist: int = ChunkLoaderService.global_view_distance
	var active_locale: String = TranslationServer.get_locale()
	
	var main_window: Window = get_tree().root
	var win_mode: int = int(main_window.mode)
	var win_size: Vector2i = main_window.size
	var username: String = _name_edit.text.strip_edges() if is_instance_valid(_name_edit) else "Player"
	
	SettingsRepository.save_settings(
		music_val,
		sfx_val,
		render_dist,
		active_locale,
		win_mode,
		win_size,
		username
	)


func _get_or_create_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx
