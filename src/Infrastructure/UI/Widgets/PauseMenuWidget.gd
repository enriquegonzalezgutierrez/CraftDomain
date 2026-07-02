# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for building and managing 
#              the Pause Menu overlay and its button interactions.
#              COMMERCIAL UI OVERHAUL (TACTILE DESIGN):
#              - Glassmorphic Card Base: Housed inside a tight, beautiful 
#                translucent panel mirroring the main menu styling.
#              - Tactile Buttons: Features physical 3D button styling that 
#                depresses visually on click, complete with hover scaling.
#              - Elastic Transitions: Smooth bounce and fade-in when toggled.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only manages pause menu presentation.
#              BUG FIX (RESPONSIVE ALIGNMENT):
#              - Connected `item_rect_changed` to dynamically calculate the 
#                card's `pivot_offset` to guarantee perfect, central scaling 
#                transitions without sliding off-center horizontally.
#              - Applied dual grow directions on containers for absolute centering.
#              WARNING FIX: Applied 100% strict static typing to all variables.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/PauseMenuWidget.gd
# ==============================================================================
class_name PauseMenuWidget
extends Panel

var hud_orchestrator: PlayerHUD
var _settings_overlay: SettingsMenu

# Card Container for animations
var _menu_card: Panel


func _ready() -> void:
	name = "PauseMenuWidget"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Full-screen dark translucent backdrop wash
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	add_theme_stylebox_override("panel", bg_style)
	
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Enforce dual-centered growth directions
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)
	
	# Glassmorphic Card Base (Consistent with main menu layout)
	_menu_card = Panel.new()
	_menu_card.custom_minimum_size = Vector2(380, 0) # Tightly sized
	_menu_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	card_style.set_corner_radius_all(12)
	card_style.border_width_left = 1; card_style.border_width_top = 1
	card_style.border_width_right = 1; card_style.border_width_bottom = 1
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.08) # Sleek micro-border
	card_style.shadow_size = 35; card_style.shadow_color = Color(0, 0, 0, 0.5)
	_menu_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_menu_card)
	
	# Dynamic pivot calculations to prevent sliding off-center during scale transitions!
	_menu_card.item_rect_changed.connect(func() -> void:
		_menu_card.pivot_offset = _menu_card.size / 2.0
	)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_menu_card.add_child(margin)
	
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	
	# Title
	var title: Label = Label.new()
	title.text = tr("HUD_PAUSE_TITLE").to_upper() # Localized
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var title_style: LabelSettings = LabelSettings.new()
	title_style.font_size = 28
	title_style.font_color = Color(1.0, 0.85, 0.2)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	title.label_settings = title_style
	box.add_child(title)
	
	box.add_child(_create_spacer(14))
	
	# Spawns Tactile Buttons
	var resume_btn: Button = _create_tactile_button(Color(0.15, 0.55, 0.35, 1.0)) # Accent Green
	resume_btn.text = tr("HUD_PAUSE_RESUME")
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)
	
	var default_color: Color = Color(0.2, 0.2, 0.24, 1.0)
	
	var settings_btn: Button = _create_tactile_button(default_color)
	settings_btn.text = tr("HUD_PAUSE_SETTINGS")
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	var quit_btn: Button = _create_tactile_button(Color(0.15, 0.15, 0.18, 1.0))
	quit_btn.text = tr("HUD_PAUSE_QUIT")
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)
	
	# Adapt card height dynamically
	_menu_card.size.y = box.get_minimum_size().y + 60
	_menu_card.custom_minimum_size.y = _menu_card.size.y

	visible = false


## Factory method to programmatically construct 3D tactile buttons
func _create_tactile_button(base_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var shadow_color: Color = base_color.darkened(0.4)
	
	# Normal State (3D Pop out)
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4 # Thick tactile depth
	sn.border_color = shadow_color
	
	# Hover State
	var sh: StyleBoxFlat = sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	
	# Pressed State
	var sp: StyleBoxFlat = StyleBoxFlat.new()
	sp.bg_color = shadow_color
	sp.set_corner_radius_all(8)
	sp.border_width_top = 4
	sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# Dynamic pivot calculations for hover scale effects
	btn.item_rect_changed.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	
	btn.mouse_entered.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	return btn


func toggle_menu(p_visible: bool) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	
	if p_visible:
		visible = true
		modulate.a = 0.0
		_menu_card.scale = Vector2(0.95, 0.95)
		
		tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(_menu_card, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
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
	# FIX: Explicit static typing on Bootstrap query reference
	var bootstrap: Bootstrap = get_node_or_null("/root/Bootstrap") as Bootstrap
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")


func _create_spacer(height: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
