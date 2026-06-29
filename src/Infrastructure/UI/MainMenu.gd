# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing the main menu overlay.
#              UX IMPROVED: Added premium glassmorphic button styling, tactile 
#              hover scale animations, and a floating sine-wave game title.
#              SAVE SYSTEM UPGRADE: Added dynamic CONTINUE / NEW GAME detection.
#              NEW GAME CONFIRMATION: Added a glassmorphic confirmation modal 
#              that automatically wipes old JSON save files and chunks from disk!
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MainMenu.gd
# ==============================================================================
class_name MainMenu
extends Control

## Emitted when the player requests to launch the world (new or loaded)
signal play_pressed

# STRICT MODE FIX: Statically type the variable to its concrete class
var _settings_overlay: SettingsMenu
var _title_label: Label
var _time_passed: float = 0.0

# Confirmation Modal Nodes
var _confirm_modal: Panel
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
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	
	# 5. Create Dynamic Premium Buttons based on Save State
	if _has_save_game:
		var continue_btn := _create_premium_button("CONTINUE GAME", Color(0.12, 0.55, 0.32, 0.7)) # Greenish glow
		continue_btn.pressed.connect(_on_continue_pressed)
		box.add_child(continue_btn)
		box.add_child(_create_spacer(15))
		
		var new_game_btn := _create_premium_button("NEW GAME (RESET)", Color(0.1, 0.1, 0.12, 0.7))
		new_game_btn.pressed.connect(_on_new_game_clicked_with_save)
		box.add_child(new_game_btn)
	else:
		var play_btn := _create_premium_button("NEW GAME", Color(0.12, 0.55, 0.82, 0.7)) # Blueish glow
		play_btn.pressed.connect(_on_play_pressed)
		box.add_child(play_btn)
	
	box.add_child(_create_spacer(15))
	
	var settings_btn := _create_premium_button("SETTINGS", Color(0.1, 0.1, 0.12, 0.7))
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	box.add_child(_create_spacer(15))
	
	var exit_btn := _create_premium_button("EXIT GAME", Color(0.1, 0.1, 0.12, 0.7))
	exit_btn.pressed.connect(_on_exit_pressed)
	box.add_child(exit_btn)
	
	# 6. Setup confirmation Modal (Hidden by default)
	_setup_confirmation_modal()

func _process(delta: float) -> void:
	if is_instance_valid(_title_label):
		_time_passed += delta * 2.0
		_title_label.position.y = sin(_time_passed) * 8.0

## Factory method to programmatically construct highly polished glassmorphic buttons
func _create_premium_button(text: String, normal_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 55)
	btn.pivot_offset = Vector2(140, 27.5)
	
	# Normal State Style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = normal_color
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
	style_hover.bg_color = normal_color + Color(0.08, 0.08, 0.08, 0.0)
	style_hover.set_corner_radius_all(12)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1.0, 0.85, 0.2, 1.0) # Golden glow
	style_hover.shadow_size = 8
	style_hover.shadow_color = Color(0, 0, 0, 0.5)
	
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
	cs.border_width_left = 2
	cs.border_width_top = 2
	cs.border_width_right = 2
	cs.border_width_bottom = 2
	cs.border_color = Color(0.85, 0.15, 0.15, 0.6) # Red warning border
	cs.shadow_size = 15
	cs.shadow_color = Color(0, 0, 0, 0.6)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "⚠️ OVERWRITE PROGRESS?"
	var ts := LabelSettings.new()
	ts.font_size = 20
	ts.font_color = Color(0.95, 0.15, 0.15) # Warning Red
	ts.outline_size = 3
	ts.outline_color = Color.BLACK
	title.label_settings = ts
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(_create_spacer(10))
	
	var desc := Label.new()
	desc.text = "Warning: Starting a new game will permanently delete your saved castle, inventory blocks, and quest progression on disk. This cannot be undone."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ds := LabelSettings.new()
	ds.font_size = 12
	ds.font_color = Color(0.85, 0.85, 0.9)
	desc.label_settings = ds
	vbox.add_child(desc)
	
	vbox.add_child(_create_spacer(20))
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	var confirm_btn := Button.new()
	confirm_btn.text = "DELETE & OVERWRITE"
	confirm_btn.custom_minimum_size = Vector2(180, 42)
	_setup_modal_button_style(confirm_btn, Color(0.7, 0.12, 0.12, 0.8)) # Hard Red
	confirm_btn.pressed.connect(_on_overwrite_confirmed)
	hbox.add_child(confirm_btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(120, 42)
	_setup_modal_button_style(cancel_btn, Color(0.2, 0.2, 0.25, 0.8)) # Gray
	cancel_btn.pressed.connect(_on_overwrite_cancelled)
	hbox.add_child(cancel_btn)
	
	_confirm_modal.visible = false
	add_child(_confirm_modal)

func _setup_modal_button_style(btn: Button, color: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = color
	sn.set_corner_radius_all(8)
	sn.border_width_left = 1
	sn.border_width_top = 1
	sn.border_width_right = 1
	sn.border_width_bottom = 1
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

func _on_continue_pressed() -> void:
	print("[MainMenu] Continuing existing campaign exploration...")
	play_pressed.emit()

func _on_new_game_clicked_with_save() -> void:
	# Show warning overlay
	_confirm_modal.visible = true
	_confirm_modal.modulate.a = 0.0
	_confirm_modal.scale = Vector2(0.95, 0.96)
	_confirm_modal.pivot_offset = Vector2(640, 360)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK)

func _on_overwrite_confirmed() -> void:
	_confirm_modal.visible = false
	_delete_save_files_on_disk()
	play_pressed.emit()

func _on_overwrite_cancelled() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_confirm_modal, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void: _confirm_modal.visible = false)

## UX / DISK HARD DISPOSAL: Deletes all previous campaign and chunk JSONs on disk
func _delete_save_files_on_disk() -> void:
	print("[MainMenu] Deleting old save directory contents on player request...")
	
	# 1. Delete main save
	if FileAccess.file_exists("user://world_save/global_save.json"):
		DirAccess.remove_absolute("user://world_save/global_save.json")
		
	# 2. Sweep all chunk modification files
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

func _on_play_pressed() -> void:
	# Fresh start (no save detected, no confirm needed)
	play_pressed.emit()

func _on_settings_pressed() -> void:
	_settings_overlay = SettingsMenu.new()
	_settings_overlay.connect("closed", Callable(self, "_on_settings_closed"))
	add_child(_settings_overlay)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
