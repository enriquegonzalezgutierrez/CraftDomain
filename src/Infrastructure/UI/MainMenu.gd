# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing the main menu overlay.
#              SOLID COMPLIANCE: Adheres to SRP by handling only menu presentation.
#              i18n UPGRADE: Uses standardized translation keys (OCP compliant).
#              REACTIVITY: Implements NOTIFICATION_TRANSLATION_CHANGED with safe
#              lifecycle guards to prevent "Nil text assignment" crashes during boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MainMenu.gd
# ==============================================================================
class_name MainMenu
extends Control

## Emitted when the player requests to launch the world (new or loaded)
signal play_pressed

# STRICT TYPING: Private references to settings overlays and animators
var _settings_overlay: SettingsMenu
var _title_label: Label
var _time_passed: float = 0.0

# Dynamic button references for locale refreshes
var _play_continue_btn: Button
var _reset_btn: Button
var _settings_btn: Button
var _exit_btn: Button

# Confirmation Modal Nodes
var _confirm_modal: Panel
var _modal_title: Label
var _modal_desc: Label
var _modal_confirm_btn: Button
var _modal_cancel_btn: Button

var _has_save_game: bool = false

func _ready() -> void:
	# Stretch the root control node to fill the entire window viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Detect if a save game already exists on disk
	_has_save_game = FileAccess.file_exists("user://world_save/global_save.json")
	
	# 1. Background texture
	var bg := TextureRect.new()
	bg.name = "MenuBackground"
	bg.texture = load("res://src/Infrastructure/UI/Assets/menu_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Dark translucent wash
	var wash := ColorRect.new()
	wash.name = "ColorWash"
	wash.color = Color(0.05, 0.05, 0.08, 0.6) 
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
	settings.font_color = Color(1.0, 0.95, 0.85) 
	settings.outline_size = 12
	settings.outline_color = Color(0.08, 0.08, 0.08) 
	settings.shadow_size = 8
	settings.shadow_color = Color(0, 0, 0, 0.5)
	settings.shadow_offset = Vector2(0, 5)
	_title_label.label_settings = settings
	
	var title_wrapper := Control.new()
	title_wrapper.custom_minimum_size = Vector2(500, 100)
	title_wrapper.add_child(_title_label)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_child(title_wrapper)
	
	box.add_child(_create_spacer(30))
	
	# 5. Instantiate all UI buttons programmatically (Texts assigned in refresh)
	_play_continue_btn = _create_premium_button(Color(0.12, 0.55, 0.32, 0.7) if _has_save_game else Color(0.12, 0.55, 0.82, 0.7))
	_play_continue_btn.pressed.connect(_on_play_pressed)
	box.add_child(_play_continue_btn)
	
	if _has_save_game:
		box.add_child(_create_spacer(15))
		_reset_btn = _create_premium_button(Color(0.1, 0.1, 0.12, 0.7))
		_reset_btn.pressed.connect(_on_new_game_clicked_with_save)
		box.add_child(_reset_btn)
		
	box.add_child(_create_spacer(15))
	
	_settings_btn = _create_premium_button(Color(0.1, 0.1, 0.12, 0.7))
	_settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(_settings_btn)
	
	box.add_child(_create_spacer(15))
	
	_exit_btn = _create_premium_button(Color(0.1, 0.1, 0.12, 0.7))
	_exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(_exit_btn)
	
	# 6. Setup confirmation Modal (Hidden by default)
	_setup_confirmation_modal()
	
	# 7. Render dynamic localized texts
	_refresh_localized_text()

## REACTIVITY: Captures dynamic i18n locale changes from Godot's Translation Server on-the-fly
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()

func _process(delta: float) -> void:
	if is_instance_valid(_title_label):
		_time_passed += delta * 2.0
		_title_label.position.y = sin(_time_passed) * 8.0

## Dynamically refreshes all visible text elements with the active translation database
## FIXED: Added strict is_instance_valid() checks to prevent early SceneTree call crashes.
func _refresh_localized_text() -> void:
	if _has_save_game:
		if is_instance_valid(_play_continue_btn):
			_play_continue_btn.text = tr("MENU_CONTINUE")
		if is_instance_valid(_reset_btn):
			_reset_btn.text = tr("MENU_NEW_GAME")
	else:
		if is_instance_valid(_play_continue_btn):
			_play_continue_btn.text = tr("MENU_PLAY_WORLD")
			
	if is_instance_valid(_settings_btn):
		_settings_btn.text = tr("MENU_SETTINGS")
	if is_instance_valid(_exit_btn):
		_exit_btn.text = tr("MENU_EXIT")
		
	# Overwrite warning modal translations (Guarded against Null/Early calls)
	if is_instance_valid(_modal_title):
		_modal_title.text = tr("MENU_RESET_WARNING_TITLE")
	if is_instance_valid(_modal_desc):
		_modal_desc.text = tr("MENU_RESET_WARNING_DESC")
	if is_instance_valid(_modal_confirm_btn):
		_modal_confirm_btn.text = tr("MENU_RESET_CONFIRM")
	if is_instance_valid(_modal_cancel_btn):
		_modal_cancel_btn.text = tr("MENU_RESET_CANCEL")

## Factory method to programmatically construct highly polished glassmorphic buttons
func _create_premium_button(normal_color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 55)
	btn.pivot_offset = Vector2(140, 27.5)
	
	# Normal State Style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = normal_color
	style_normal.set_corner_radius_all(12)
	style_normal.border_width_left = 2; style_normal.border_width_top = 2; style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.35, 0.8)
	style_normal.shadow_size = 4; style_normal.shadow_color = Color(0, 0, 0, 0.3)
	
	# Hover State Style (Brighter with Golden Border)
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = normal_color + Color(0.08, 0.08, 0.08, 0.0)
	style_hover.set_corner_radius_all(12)
	style_hover.border_width_left = 2; style_hover.border_width_top = 2; style_hover.border_width_right = 2; style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1.0, 0.85, 0.2, 1.0) # Golden glow
	style_hover.shadow_size = 8; style_hover.shadow_color = Color(0, 0, 0, 0.5)
	
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = normal_color - Color(0.05, 0.05, 0.05, 0.0)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	
	return btn

## Creates a premium glassmorphic warning modal to protect saves
func _setup_confirmation_modal() -> void:
	_confirm_modal = Panel.new()
	_confirm_modal.name = "ConfirmationModal"
	_confirm_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.7) # Dark backdrop wash
	_confirm_modal.add_theme_stylebox_override("panel", bg_style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_modal.add_child(center)
	
	var card := Panel.new()
	card.custom_minimum_size = Vector2(460, 260)
	card.size = Vector2(460, 260)
	var cs := StyleBoxFlat.new()
	cs.set_corner_radius_all(14)
	cs.bg_color = Color(0.08, 0.08, 0.1, 0.96)
	cs.border_width_left = 2; cs.border_width_top = 2; cs.border_width_right = 2; cs.border_width_bottom = 2
	cs.border_color = Color(0.85, 0.15, 0.15, 0.6) # Red warning border
	cs.shadow_size = 15; cs.shadow_color = Color(0, 0, 0, 0.6)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24); margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24); margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	_modal_title = Label.new()
	var ts := LabelSettings.new(); ts.font_size = 20; ts.font_color = Color(0.95, 0.15, 0.15); ts.outline_size = 3; ts.outline_color = Color.BLACK
	_modal_title.label_settings = ts; _modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modal_title)
	
	vbox.add_child(_create_spacer(10))
	
	_modal_desc = Label.new()
	_modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD; _modal_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ds := LabelSettings.new(); ds.font_size = 12; ds.font_color = Color(0.85, 0.85, 0.9)
	_modal_desc.label_settings = ds
	vbox.add_child(_modal_desc)
	
	vbox.add_child(_create_spacer(20))
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	_modal_confirm_btn = Button.new()
	_modal_confirm_btn.custom_minimum_size = Vector2(180, 42)
	_setup_modal_button_style(_modal_confirm_btn, Color(0.7, 0.12, 0.12, 0.8)) # Hard Red
	_modal_confirm_btn.pressed.connect(_on_overwrite_confirmed)
	hbox.add_child(_modal_confirm_btn)
	
	_modal_cancel_btn = Button.new()
	_modal_cancel_btn.custom_minimum_size = Vector2(120, 42)
	_setup_modal_button_style(_modal_cancel_btn, Color(0.2, 0.2, 0.25, 0.8)) # Gray
	_modal_cancel_btn.pressed.connect(_on_overwrite_cancelled)
	hbox.add_child(_modal_cancel_btn)
	
	_confirm_modal.visible = false
	add_child(_confirm_modal)

func _setup_modal_button_style(btn: Button, color: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = color
	sn.set_corner_radius_all(8)
	sn.border_width_left = 1; sn.border_width_top = 1; sn.border_width_right = 1; sn.border_width_bottom = 1
	sn.border_color = Color(1.0, 1.0, 1.0, 0.15)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9) # Gold
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 13)

func _create_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _on_play_pressed() -> void:
	play_pressed.emit()

func _on_new_game_clicked_with_save() -> void:
	# Show warning overlay with scale animation
	_confirm_modal.visible = true
	_confirm_modal.modulate.a = 0.0
	_confirm_modal.scale = Vector2(0.95, 0.96)
	_confirm_modal.pivot_offset = get_viewport_rect().size / 2.0
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK)

func _on_overwrite_confirmed() -> void:
	_confirm_modal.visible = false
	_has_save_game = false
	_setup_starting_play_button_layout()
	_delete_save_files_on_disk()
	play_pressed.emit()

func _setup_starting_play_button_layout() -> void:
	if is_instance_valid(_play_continue_btn):
		var style := _play_continue_btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style != null:
			style.bg_color = Color(0.12, 0.55, 0.82, 0.7) # Smooth back to solid Blue
	if is_instance_valid(_reset_btn):
		_reset_btn.queue_free()

func _on_overwrite_cancelled() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void: _confirm_modal.visible = false)

func _delete_save_files_on_disk() -> void:
	var global_path := "user://world_save/global_save.json"
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
		
	var chunks_dir := "user://world_save/chunks/"
	if DirAccess.dir_exists_absolute(chunks_dir):
		var dir := DirAccess.open(chunks_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			
	print("[MainMenu] Save wiping finished successfully. Ready for a new world!")

func _on_settings_pressed() -> void:
	_settings_overlay = SettingsMenu.new()
	_settings_overlay.closed.connect(_on_settings_closed)
	add_child(_settings_overlay)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
