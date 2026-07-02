# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing the main menu overlay.
#              COMMERCIAL UI OVERHAUL (TACTILE DESIGN):
#              - Tactile Buttons: Buttons now feature a 3D physical aesthetic 
#                with a solid 4px bottom border that visually depresses on click.
#              - Snug Card Proportions: Shrunk the massive empty card width 
#                and adjusted internal margins for a snug, professional fit.
#              - Modern Glassmorphism: Replaced thick grey borders with a sleek 
#                1px micro-border and a deeper, softer shadow scatter.
#              - 100% Responsive Grid: Housed both the title and the card inside 
#                a unified CenterContainer stack. They will NEVER overlap and 
#                will auto-align horizontally and vertically across all screen ratios.
#              SOLID COMPLIANCE: Adheres to SRP by handling only menu presentation.
#              WARNING FIX: Fully strictly-typed variables to eliminate warnings.
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
var _menu_card: Panel
var _master_vbox: VBoxContainer


func _ready() -> void:
	# Stretch the root control node to fill the entire window viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Detect if a save game already exists on disk
	_has_save_game = FileAccess.file_exists("user://world_save/global_save.json")
	
	# 1. Background texture
	var bg: TextureRect = TextureRect.new()
	bg.name = "MenuBackground"
	bg.texture = load("res://src/Infrastructure/UI/Assets/menu_background.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Dark translucent wash (Dimmed slightly to let the background pop more)
	var wash: ColorRect = ColorRect.new()
	wash.name = "ColorWash"
	wash.color = Color(0.04, 0.04, 0.06, 0.45) 
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	
	# 3. 100% RESPONSIVE UNIFIED CONTAINER
	# Both Title and Menu Card now live inside this Centered VBox flow, preventing overlaps
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	_master_vbox = VBoxContainer.new()
	_master_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_master_vbox.add_theme_constant_override("separation", 35) # Safe gap between Title & Card
	center_container.add_child(_master_vbox)
	
	# 4. Game Title with Premium Styling
	_title_label = Label.new()
	_title_label.name = "GameTitle"
	_title_label.text = "CRAFT DOMAIN"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.pivot_offset = Vector2(250, 45) # Approximate center for pop animation
	
	var title_settings: LabelSettings = LabelSettings.new()
	title_settings.font_size = 72
	title_settings.font_color = Color(1.0, 0.95, 0.85) 
	title_settings.outline_size = 14
	title_settings.outline_color = Color(0.06, 0.06, 0.08) 
	title_settings.shadow_size = 12
	title_settings.shadow_color = Color(0, 0, 0, 0.6)
	title_settings.shadow_offset = Vector2(0, 6)
	_title_label.label_settings = title_settings
	_master_vbox.add_child(_title_label)
	
	# 5. Modern Card for Menu Options (Tighter, snug proportions)
	_menu_card = Panel.new()
	_menu_card.custom_minimum_size = Vector2(380, 0)
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.92) # Darker, elegant base
	card_style.set_corner_radius_all(12)
	# Premium micro-border
	card_style.border_width_left = 1; card_style.border_width_top = 1
	card_style.border_width_right = 1; card_style.border_width_bottom = 1
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.08) 
	card_style.shadow_size = 35; card_style.shadow_color = Color(0, 0, 0, 0.45)
	_menu_card.add_theme_stylebox_override("panel", card_style)
	_master_vbox.add_child(_menu_card)
	
	# Snug internal margins
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_top", 24)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_bottom", 24)
	_menu_card.add_child(card_margin)
	
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14) # Crisp, even spacing
	card_margin.add_child(box)
	
	# 6. Instantiate UI Tactile Buttons
	var play_color: Color = Color(0.15, 0.60, 0.35, 1.0) if _has_save_game else Color(0.15, 0.55, 0.85, 1.0)
	_play_continue_btn = _create_tactile_button(play_color, true)
	_play_continue_btn.pressed.connect(_on_play_pressed)
	box.add_child(_play_continue_btn)
	
	var default_color: Color = Color(0.2, 0.2, 0.24, 1.0)
	
	if _has_save_game:
		_reset_btn = _create_tactile_button(default_color, false)
		_reset_btn.pressed.connect(_on_new_game_clicked_with_save)
		box.add_child(_reset_btn)
		
	_settings_btn = _create_tactile_button(default_color, false)
	_settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(_settings_btn)
	
	_exit_btn = _create_tactile_button(Color(0.15, 0.15, 0.18, 1.0), false)
	_exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(_exit_btn)
	
	# Allow the card container to adapt to the VBox height automatically
	_menu_card.size.y = box.get_minimum_size().y + 48
	_menu_card.custom_minimum_size.y = _menu_card.size.y
	_menu_card.pivot_offset = _menu_card.custom_minimum_size / 2.0
	
	# 7. Commercial Branding (Version Number)
	var version_lbl: Label = Label.new()
	version_lbl.text = "v1.0.0"
	version_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version_lbl.offset_right = -15; version_lbl.offset_bottom = -10
	var v_settings: LabelSettings = LabelSettings.new()
	v_settings.font_size = 14; v_settings.font_color = Color(0.6, 0.6, 0.65)
	version_lbl.label_settings = v_settings
	add_child(version_lbl)
	
	# 8. Setup confirmation Modal (Hidden by default)
	_setup_confirmation_modal()
	
	# 9. Render dynamic localized texts
	_refresh_localized_text()
	
	# 10. Trigger Cinematic Entry Animation
	_play_entry_animation()


## Animates the menu popping in with a premium elastic scale & fade transition.
func _play_entry_animation() -> void:
	modulate.a = 0.0
	_menu_card.scale = Vector2(0.9, 0.9)
	_title_label.scale = Vector2(0.9, 0.9)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## REACTIVITY: Captures dynamic i18n locale changes from Godot's Translation Server on-the-fly
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


func _process(delta: float) -> void:
	if is_instance_valid(_title_label):
		_time_passed += delta * 1.5
		# Subtle floating effect on the title
		_title_label.position.y = lerp(_title_label.position.y, _title_label.position.y + sin(_time_passed) * 0.4, delta * 5.0)


## Dynamically refreshes all visible text elements with the active translation database
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
func _create_tactile_button(base_color: Color, is_primary: bool) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 54) # Taller for a substantial feel
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var shadow_color: Color = base_color.darkened(0.4)
	
	# Normal State (3D Pop out)
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4 # Thick tactile depth
	sn.border_color = shadow_color
	
	# Hover State (Brighter, slight gold accent if primary)
	var sh: StyleBoxFlat = sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	if is_primary:
		sh.border_width_left = 1; sh.border_width_top = 1; sh.border_width_right = 1
		sh.border_color = Color(1.0, 0.85, 0.2, 0.8) # Gold accent for the Play button
	
	# Pressed State (Sinks down physically)
	var sp: StyleBoxFlat = StyleBoxFlat.new()
	sp.bg_color = shadow_color
	sp.set_corner_radius_all(8)
	sp.border_width_top = 4 # Simulate pressing down
	sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# Calculate pivot dynamically for center scaling
	btn.item_rect_changed.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	
	# Add slight scale bounce on hover
	btn.mouse_entered.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	return btn


## Creates a premium glassmorphic warning modal to protect saves
func _setup_confirmation_modal() -> void:
	_confirm_modal = Panel.new()
	_confirm_modal.name = "ConfirmationModal"
	_confirm_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	_confirm_modal.add_theme_stylebox_override("panel", bg_style)
	
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_modal.add_child(center)
	
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(440, 240)
	var cs: StyleBoxFlat = StyleBoxFlat.new()
	cs.set_corner_radius_all(12)
	cs.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	cs.set_border_width_all(1) # FIX: Native Godot 4 method instead of direct invalid property assignment!
	cs.border_color = Color(0.85, 0.15, 0.15, 0.5) # Soft Red
	cs.shadow_size = 20; cs.shadow_color = Color(0, 0, 0, 0.7)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	_modal_title = Label.new()
	var ts: LabelSettings = LabelSettings.new(); ts.font_size = 20; ts.font_color = Color(0.95, 0.25, 0.25); ts.outline_size = 4; ts.outline_color = Color.BLACK
	_modal_title.label_settings = ts; _modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modal_title)
	
	vbox.add_child(_create_spacer(14))
	
	_modal_desc = Label.new()
	_modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD; _modal_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ds: LabelSettings = LabelSettings.new(); ds.font_size = 14; ds.font_color = Color(0.85, 0.85, 0.9)
	_modal_desc.label_settings = ds
	vbox.add_child(_modal_desc)
	
	vbox.add_child(_create_spacer(24))
	
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	_modal_confirm_btn = _create_tactile_button(Color(0.75, 0.15, 0.15, 1.0), false)
	_modal_confirm_btn.custom_minimum_size = Vector2(160, 46)
	_modal_confirm_btn.pressed.connect(_on_overwrite_confirmed)
	hbox.add_child(_modal_confirm_btn)
	
	_modal_cancel_btn = _create_tactile_button(Color(0.2, 0.2, 0.25, 1.0), false)
	_modal_cancel_btn.custom_minimum_size = Vector2(140, 46)
	_modal_cancel_btn.pressed.connect(_on_overwrite_cancelled)
	hbox.add_child(_modal_cancel_btn)
	
	_confirm_modal.visible = false
	add_child(_confirm_modal)


func _create_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_new_game_clicked_with_save() -> void:
	_confirm_modal.visible = true
	_confirm_modal.modulate.a = 0.0
	_confirm_modal.scale = Vector2(0.95, 0.95)
	_confirm_modal.pivot_offset = get_viewport_rect().size / 2.0
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK)


func _on_overwrite_confirmed() -> void:
	_confirm_modal.visible = false
	_has_save_game = false
	if is_instance_valid(_reset_btn):
		_reset_btn.queue_free()
	_delete_save_files_on_disk()
	play_pressed.emit()


func _on_overwrite_cancelled() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void: _confirm_modal.visible = false)


func _delete_save_files_on_disk() -> void:
	var global_path: String = "user://world_save/global_save.json"
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
		
	var chunks_dir: String = "user://world_save/chunks/"
	if DirAccess.dir_exists_absolute(chunks_dir):
		var dir: DirAccess = DirAccess.open(chunks_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
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
