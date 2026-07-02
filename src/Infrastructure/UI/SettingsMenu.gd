# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI component providing a dynamic Settings menu
#              to control Music Volume, SFX Volume, Render Distance, and Display 
#              Resolutions.
#              COMMERCIAL UI OVERHAUL (TACTILE DESIGN):
#              - Glassmorphic Card Layout: Settings are beautifully framed 
#                inside a sleek, translucent panel with soft shadows.
#              - Dropdown Padding Fix: Implemented `content_margin` properties 
#                on OptionButton styleboxes to cleanly separate text from borders.
#              - Tactile Action Buttons: "Apply" and "Back" now use physical 3D 
#                button styling that depresses visually on click.
#              - Opaque Backdrop: Set full-screen wash to 98% opacity to completely 
#                block Main Menu rendering behind options.
#              - Ultra-Compact Layout: Bounded card dimensions strictly to 420x510 
#                with tight spacing to guarantee flawless rendering on 720p/HD.
#              SOLID COMPLIANCE: Adheres to SRP by managing configuration UI.
#              WARNING FIX: Applied 100% strict static typing to all variables.
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

# Cached Controls to query values upon saving
var _music_slider: HSlider
var _sfx_slider: HSlider
var _dist_slider: HSlider

var _res_opt: OptionButton
var _lang_opt: OptionButton
var _apply_btn: Button
var _back_btn: Button

# Card Container for animations
var _menu_card: Panel


func _ready() -> void:
	# Full-screen Opaque backdrop wash (To hide Main Menu completely)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.98) # Solid blocking barrier
	add_theme_stylebox_override("panel", style)
	
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Glassmorphic Card Base (Clamped size for absolute responsiveness)
	_menu_card = Panel.new()
	_menu_card.custom_minimum_size = Vector2(420, 510) # Bounded height to fit all resolutions
	_menu_card.size = Vector2(420, 510)
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	card_style.set_corner_radius_all(14)
	# Premium micro-border
	card_style.border_width_left = 1; card_style.border_width_top = 1
	card_style.border_width_right = 1; card_style.border_width_bottom = 1
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	card_style.shadow_size = 35; card_style.shadow_color = Color(0, 0, 0, 0.45)
	_menu_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_menu_card)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 25)
	_menu_card.add_child(margin)
	
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10) # Tight separation to avoid vertical bleeding
	margin.add_child(box)
	
	# 1. Main Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_style: LabelSettings = LabelSettings.new()
	title_style.font_size = 24
	title_style.font_color = Color(1.0, 0.85, 0.2) # Gold Accent
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	_title_label.label_settings = title_style
	box.add_child(_title_label)
	
	box.add_child(_create_spacer(6))
	
	# 2. Music Volume Slider
	_music_label = _create_label()
	box.add_child(_music_label)
	_music_slider = HSlider.new()
	_music_slider.min_value = -40.0 
	_music_slider.max_value = 0.0   
	_music_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("Music"))
	_music_slider.value_changed.connect(_on_music_changed)
	box.add_child(_music_slider)
	
	# 3. SFX Volume Slider
	_sfx_label = _create_label()
	box.add_child(_sfx_label)
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = -40.0
	_sfx_slider.max_value = 0.0
	_sfx_slider.value = AudioServer.get_bus_volume_db(_get_or_create_bus("SFX"))
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	box.add_child(_sfx_slider)
	
	# 4. Render Distance Slider
	_render_dist_label = _create_label()
	box.add_child(_render_dist_label)
	_dist_slider = HSlider.new()
	_dist_slider.min_value = 4.0
	_dist_slider.max_value = 14.0
	_dist_slider.step = 1.0
	_dist_slider.value = float(ChunkLoaderService.global_view_distance)
	_text_slider_val_update()
	_dist_slider.value_changed.connect(_on_render_distance_changed)
	box.add_child(_dist_slider)
	
	box.add_child(_create_spacer(8))
	
	# 5. Display Resolution Dropdown
	_res_label = _create_label()
	box.add_child(_res_label)
	
	var res_hbox: HBoxContainer = HBoxContainer.new()
	res_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_hbox.add_theme_constant_override("separation", 10)
	box.add_child(res_hbox)
	
	_res_opt = OptionButton.new()
	_res_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_option_button_style(_res_opt)
	res_hbox.add_child(_res_opt)
	
	_apply_btn = _create_tactile_button(Color(0.15, 0.60, 0.35, 1.0)) # Green Apply
	_apply_btn.custom_minimum_size = Vector2(90, 42)
	_apply_btn.pressed.connect(_on_apply_resolution_pressed)
	res_hbox.add_child(_apply_btn)
	
	# 6. Interface Language Selector
	_lang_label = _create_label()
	box.add_child(_lang_label)
	
	_lang_opt = OptionButton.new()
	_lang_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_option_button_style(_lang_opt)
	_lang_opt.add_item("English", 0)
	_lang_opt.add_item("Español", 1)
	
	var current_locale: String = TranslationServer.get_locale()
	if current_locale.begins_with("es"):
		_lang_opt.select(1)
	else:
		_lang_opt.select(0)
		
	_lang_opt.item_selected.connect(_on_language_changed)
	box.add_child(_lang_opt)
	
	box.add_child(_create_spacer(14))
	
	# 7. Back / Close Button (Triggers atomic configuration save)
	_back_btn = _create_tactile_button(Color(0.2, 0.2, 0.24, 1.0))
	_back_btn.custom_minimum_size = Vector2(0, 48)
	_back_btn.pressed.connect(func() -> void: 
		_save_all_current_settings()
		_play_exit_animation()
	)
	box.add_child(_back_btn)
	
	_menu_card.pivot_offset = _menu_card.custom_minimum_size / 2.0
	
	_refresh_localized_text()
	_setup_resolution_dropdown_state()
	_play_entry_animation()


## Animates the settings card popping in smoothly.
func _play_entry_animation() -> void:
	modulate.a = 0.0
	_menu_card.scale = Vector2(0.95, 0.95)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Animates the settings card fading out before closing.
func _play_exit_animation() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_menu_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: closed.emit())


## REACTIVITY: Captures dynamic i18n locale changes from Godot's Translation Server on-the-fly
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


## Dynamically refreshes all visible text elements with the active translation database
func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): _title_label.text = tr("SETTINGS_TITLE").to_upper()
	if is_instance_valid(_music_label): _music_label.text = tr("SETTINGS_MUSIC")
	if is_instance_valid(_sfx_label): _sfx_label.text = tr("SETTINGS_SFX")
	
	_text_slider_val_update()
		
	if is_instance_valid(_res_label): _res_label.text = tr("SETTINGS_RESOLUTION")
	if is_instance_valid(_lang_label): _lang_label.text = tr("SETTINGS_LANGUAGE")
	if is_instance_valid(_back_btn): _back_btn.text = tr("SETTINGS_BACK").to_upper()
	if is_instance_valid(_apply_btn): _apply_btn.text = tr("SETTINGS_APPLY").to_upper()
	
	if is_instance_valid(_res_opt):
		var active_index: int = _res_opt.selected
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
	var l: Label = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls: LabelSettings = LabelSettings.new()
	ls.font_size = 13 # Slightly smaller for compact elegance
	ls.font_color = Color(0.85, 0.85, 0.9)
	l.label_settings = ls
	return l


func _create_spacer(h: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


## Factory method for creating highly polished 3D tactile buttons
func _create_tactile_button(base_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var shadow_color: Color = base_color.darkened(0.4)
	
	# Normal State (3D Pop out)
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4 # Thick tactile depth
	sn.border_color = shadow_color
	
	# Hover State (Brighter)
	var sh: StyleBoxFlat = sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	
	# Pressed State (Sinks down physically)
	var sp: StyleBoxFlat = StyleBoxFlat.new()
	sp.bg_color = shadow_color
	sp.set_corner_radius_all(8)
	sp.border_width_top = 4
	sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# Calculate pivot dynamically for center scaling
	btn.item_rect_changed.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	
	btn.mouse_entered.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	return btn


## Clean styling for Godot OptionButtons, resolving the missing padding issue!
func _setup_option_button_style(opt: OptionButton) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.10, 0.10, 0.12, 1.0)
	style_normal.set_corner_radius_all(8)
	style_normal.set_border_width_all(1) # FIX: Native Godot 4 method instead of direct invalid property assignment!
	style_normal.border_color = Color(0.3, 0.3, 0.35, 0.8)
	
	# FIX: Add internal padding so text does not hug the borders
	style_normal.content_margin_left = 16.0
	style_normal.content_margin_right = 16.0
	style_normal.content_margin_top = 8.0
	style_normal.content_margin_bottom = 8.0
	
	var style_hover: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.14, 0.14, 0.16, 1.0)
	style_hover.border_color = Color(1.0, 0.85, 0.2, 0.8) # Gold highlight on hover
	
	opt.add_theme_stylebox_override("normal", style_normal)
	opt.add_theme_stylebox_override("hover", style_hover)
	opt.add_theme_stylebox_override("pressed", style_normal)
	opt.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	opt.add_theme_font_size_override("font_size", 14)


## Safely locates an Audio Bus by name, or creates it programmatically if it doesn't exist
func _get_or_create_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx


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
		print("[SettingsMenu] Resolution ignored inside Godot Editor debug wrapper.")
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
			
	# Save changes on resolution apply
	_save_all_current_settings()


func _on_language_changed(index: int) -> void:
	if index == 0:
		TranslationServer.set_locale("en")
	elif index == 1:
		TranslationServer.set_locale("es")
		
	# Save changes on language swap
	_save_all_current_settings()


## Persistent Writer: Extracts state values and commits them globally to disk.
func _save_all_current_settings() -> void:
	var music_val: float = _music_slider.value if is_instance_valid(_music_slider) else -6.0
	var sfx_val: float = _sfx_slider.value if is_instance_valid(_sfx_slider) else -6.0
	var render_dist: int = ChunkLoaderService.global_view_distance
	var active_locale: String = TranslationServer.get_locale()
	
	var main_window: Window = get_tree().root
	var win_mode: int = int(main_window.mode)
	var win_size: Vector2i = main_window.size
	
	SettingsRepository.save_settings(
		music_val,
		sfx_val,
		render_dist,
		active_locale,
		win_mode,
		win_size
	)
