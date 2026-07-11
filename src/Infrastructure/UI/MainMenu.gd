# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (UI Presentation / Main Menu)
# Class: MainMenu
# Description: Glassmorphic Main Menu controller. Coordinates game boots, 
#              system settings overlays, and launches the diagnostic AI Showcase.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively main menu 
#   card animations, button clicks, and layout transitions, delegating 
#   low-level file deletion transactions to the repository.
# - Open-Closed Principle (OCP): Dynamically reacts to localized translation 
#   swaps at runtime, closing the core class to modifications.
# - Liskov Substitution Principle (LSP): Fully compatible with standard Control 
#   nodes, utilizing responsive margins and centered anchors.
# ==============================================================================
class_name MainMenu
extends Control

## Emitted when the player requests to launch the world.
signal play_pressed

# References to sub-overlays
var _settings_overlay: SettingsMenu
var _title_label: Label
var _time_passed: float = 0.0

# Dynamic button references for locale refreshes
var _play_continue_btn: Button
var _reset_btn: Button
var _showcase_btn: Button # Diagnostic Test Room button
var _settings_btn: Button
var _exit_btn: Button

# Confirmation Modal Nodes
var _confirm_modal: Panel
var _modal_card: PanelContainer
var _modal_title: Label
var _modal_desc: Label
var _modal_confirm_btn: Button
var _modal_cancel_btn: Button

var _has_save_game: bool = false
var _menu_card: PanelContainer
var _master_vbox: VBoxContainer


func _ready() -> void:
	# Stretch the root control node to fill the entire window viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Detect if a save game already exists on disk
	_has_save_game = FileAccess.file_exists("user://world_save/global_save.json")
	
	# 1. Background texture
	var bg := TextureRect.new()
	bg.name = "MenuBackground"
	bg.texture = load("res://src/Infrastructure/UI/Assets/menu_background.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Dark translucent wash
	var wash := ColorRect.new()
	wash.name = "ColorWash"
	wash.color = Color(0.04, 0.04, 0.06, 0.45) 
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	
	# 3. 100% RESPONSIVE UNIFIED CONTAINER
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	_master_vbox = VBoxContainer.new()
	_master_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_master_vbox.add_theme_constant_override("separation", 35) 
	center_container.add_child(_master_vbox)
	
	# 4. Game Title
	_title_label = Label.new()
	_title_label.name = "GameTitle"
	_title_label.text = tr("MENU_GAME_TITLE").to_upper()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.pivot_offset = Vector2(250, 45)
	
	var title_settings := LabelSettings.new()
	title_settings.font_size = 72
	title_settings.font_color = Color(1.0, 0.95, 0.85) 
	title_settings.outline_size = 14
	title_settings.outline_color = Color(0.06, 0.06, 0.08) 
	title_settings.shadow_size = 12
	title_settings.shadow_color = Color(0, 0, 0, 0.6)
	title_settings.shadow_offset = Vector2(0, 6)
	_title_label.label_settings = title_settings
	_master_vbox.add_child(_title_label)
	
	# 5. Modern Card (PanelContainer for Auto-Resizing)
	_menu_card = PanelContainer.new()
	_menu_card.custom_minimum_size = Vector2(380, 0)
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	card_style.set_corner_radius_all(12)
	card_style.border_width_left = 1; card_style.border_width_top = 1
	card_style.border_width_right = 1; card_style.border_width_bottom = 1
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.08) 
	card_style.shadow_size = 35; card_style.shadow_color = Color(0, 0, 0, 0.45)
	_menu_card.add_theme_stylebox_override("panel", card_style)
	
	# Track dynamic sizing for accurate center scaling animations
	_menu_card.item_rect_changed.connect(func() -> void:
		_menu_card.pivot_offset = _menu_card.size / 2.0
	)
	_master_vbox.add_child(_menu_card)
	
	# Snug internal margins
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_top", 24)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_bottom", 24)
	_menu_card.add_child(card_margin)
	
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	card_margin.add_child(box)
	
	# 6. Instantiate UI Tactile Buttons
	var play_color := Color(0.15, 0.60, 0.35, 1.0) if _has_save_game else Color(0.15, 0.55, 0.85, 1.0)
	_play_continue_btn = _create_tactile_button(play_color)
	_play_continue_btn.pressed.connect(_on_play_pressed)
	box.add_child(_play_continue_btn)
	
	var default_color := Color(0.2, 0.2, 0.24, 1.0)
	
	if _has_save_game:
		_reset_btn = _create_tactile_button(default_color)
		_reset_btn.pressed.connect(_on_new_game_clicked_with_save)
		box.add_child(_reset_btn)
		
	# Bounded diagnostic laboratory button
	_showcase_btn = _create_tactile_button(default_color)
	_showcase_btn.pressed.connect(_on_showcase_pressed)
	box.add_child(_showcase_btn)
		
	_settings_btn = _create_tactile_button(default_color)
	_settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(_settings_btn)
	
	_exit_btn = _create_tactile_button(Color(0.15, 0.15, 0.18, 1.0))
	_exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(_exit_btn)
	
	# 7. Commercial Branding
	var version_lbl := Label.new()
	version_lbl.text = "v1.0.0"
	version_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version_lbl.offset_right = -15; version_lbl.offset_bottom = -10
	var v_settings := LabelSettings.new()
	v_settings.font_size = 14; v_settings.font_color = Color(0.6, 0.6, 0.65)
	version_lbl.label_settings = v_settings
	add_child(version_lbl)
	
	# 8. Setup confirmation Modal (Hidden by default)
	_setup_confirmation_modal()
	
	# 9. Render dynamic localized texts
	_refresh_localized_text()
	
	# 10. Trigger Cinematic Entry Animation
	_play_entry_animation()


func _play_entry_animation() -> void:
	modulate.a = 0.0
	_menu_card.scale = Vector2(0.9, 0.9)
	_title_label.scale = Vector2(0.9, 0.9)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


func _process(delta: float) -> void:
	if is_instance_valid(_title_label):
		_time_passed += delta * 1.5
		_title_label.position.y = lerp(_title_label.position.y, _title_label.position.y + sin(_time_passed) * 0.4, delta * 5.0)


## Translates all UI strings based on the active loaded locale language file
func _refresh_localized_text() -> void:
	if _has_save_game:
		if is_instance_valid(_play_continue_btn):
			_play_continue_btn.text = tr("MENU_CONTINUE")
		if is_instance_valid(_reset_btn):
			_reset_btn.text = tr("MENU_NEW_GAME")
	else:
		if is_instance_valid(_play_continue_btn):
			_play_continue_btn.text = tr("MENU_PLAY_WORLD")
			
	if is_instance_valid(_showcase_btn):
		_showcase_btn.text = tr("MENU_ASSET_SHOWCASE")
	if is_instance_valid(_settings_btn):
		_settings_btn.text = tr("MENU_SETTINGS")
	if is_instance_valid(_exit_btn):
		_exit_btn.text = tr("MENU_EXIT")
		
	# Overwrite warning modal translations
	if is_instance_valid(_modal_title):
		_modal_title.text = tr("MENU_RESET_WARNING_TITLE")
	if is_instance_valid(_modal_desc):
		_modal_desc.text = tr("MENU_RESET_WARNING_DESC")
	if is_instance_valid(_modal_confirm_btn):
		_modal_confirm_btn.text = tr("MENU_RESET_CONFIRM")
	if is_instance_valid(_modal_cancel_btn):
		_modal_cancel_btn.text = tr("MENU_RESET_CANCEL")


## Factory method to programmatically construct highly polished 3D tactile buttons
func _create_tactile_button(base_color: Color) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var shadow_color := base_color.darkened(0.4)
	
	var sn := StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4 
	sn.border_color = shadow_color
	sn.content_margin_left = 20.0
	sn.content_margin_right = 20.0
	sn.content_margin_top = 14.0
	sn.content_margin_bottom = 14.0
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	
	var sp := sn.duplicate() as StyleBoxFlat
	sp.bg_color = shadow_color
	sp.border_width_top = 4
	sp.border_width_bottom = 0
	sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	btn.item_rect_changed.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	return btn


## Creates a premium glassmorphic warning modal to protect saves
func _setup_confirmation_modal() -> void:
	_confirm_modal = Panel.new()
	_confirm_modal.name = "ConfirmationModal"
	_confirm_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	_confirm_modal.add_theme_stylebox_override("panel", bg_style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_modal.add_child(center)
	
	_modal_card = PanelContainer.new()
	_modal_card.custom_minimum_size = Vector2(560, 0) 
	var cs := StyleBoxFlat.new()
	cs.set_corner_radius_all(12)
	cs.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	cs.set_border_width_all(1) 
	cs.border_color = Color(0.85, 0.15, 0.15, 0.5) 
	cs.shadow_size = 20; cs.shadow_color = Color(0, 0, 0, 0.7)
	_modal_card.add_theme_stylebox_override("panel", cs)
	
	_modal_card.item_rect_changed.connect(func() -> void:
		_modal_card.pivot_offset = _modal_card.size / 2.0
	)
	center.add_child(_modal_card)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_bottom", 24)
	_modal_card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	_modal_title = Label.new()
	var ts := LabelSettings.new(); ts.font_size = 20; ts.font_color = Color(0.95, 0.25, 0.25); ts.outline_size = 4; ts.outline_color = Color.BLACK
	_modal_title.label_settings = ts; _modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modal_title)
	
	vbox.add_child(_create_spacer(14))
	
	_modal_desc = Label.new()
	_modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD; _modal_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ds := LabelSettings.new(); ds.font_size = 14; ds.font_color = Color(0.85, 0.85, 0.9)
	_modal_desc.label_settings = ds
	vbox.add_child(_modal_desc)
	
	vbox.add_child(_create_spacer(24))
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20) 
	vbox.add_child(hbox)
	
	_modal_confirm_btn = _create_tactile_button(Color(0.75, 0.15, 0.15, 1.0))
	_modal_confirm_btn.pressed.connect(_on_overwrite_confirmed)
	hbox.add_child(_modal_confirm_btn)
	
	_modal_cancel_btn = _create_tactile_button(Color(0.2, 0.2, 0.25, 1.0))
	_modal_cancel_btn.pressed.connect(_on_overwrite_cancelled)
	hbox.add_child(_modal_cancel_btn)
	
	_confirm_modal.visible = false
	add_child(_confirm_modal)


func _create_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_new_game_clicked_with_save() -> void:
	_confirm_modal.visible = true
	_confirm_modal.modulate.a = 0.0
	_modal_card.scale = Vector2(0.9, 0.9)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_modal_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_overwrite_confirmed() -> void:
	_confirm_modal.visible = false
	_has_save_game = false
	if is_instance_valid(_reset_btn):
		_reset_btn.queue_free()
	
	# SRP RESOLUTION: Delegating the low-level save wiping operation to a static
	# helper inside the concrete DiskWorldRepository class, isolating disk I/O.
	DiskWorldRepository.delete_save_game_files()
	play_pressed.emit()


func _on_overwrite_cancelled() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_modal_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void: _confirm_modal.visible = false)


## Symmetrical transition into the new, fully isolated AIShowcaseRoom testing sandbox!
func _on_showcase_pressed() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func() -> void:
		var room := AIShowcaseRoom.new()
		get_parent().add_child(room)
		queue_free()
	)


func _on_settings_pressed() -> void:
	_settings_overlay = SettingsMenu.new()
	_settings_overlay.closed.connect(_on_settings_closed)
	add_child(_settings_overlay)


func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()


func _on_exit_pressed() -> void:
	get_tree().quit()
