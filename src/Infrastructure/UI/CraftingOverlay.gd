# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing an interactive, 
#              glassmorphic dual-pane Crafting and Blueprint Workshop overlay.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by managing only the layout representation and 
#              UI events, delegating the transaction rules to `CraftingService`.
#              BUG FIX (DEAD CODE): Removed legacy calls to `_sync_hud_counters`.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/CraftingOverlay.gd
# ==============================================================================
class_name CraftingOverlay
extends Panel

## Emitted when the user closes the crafting workshop
signal closed

## Reference to the player (injected on instantiation)
var player: CharacterBody3D

# UI Nodes
var _recipes_list: VBoxContainer
var _detail_panel: Panel
var _detail_title: Label
var _detail_icon: ColorRect
var _detail_requirements_box: VBoxContainer
var _craft_button: Button

# Current selection state
var _selected_recipe: Recipe = null

# Theme palette colors matching our hotbar blocks
const BLOCK_COLORS = {
	0: Color(0.55, 0.55, 0.55), # Stone
	1: Color(0.55, 0.38, 0.25), # Dirt
	2: Color(0.42, 0.78, 0.25), # Grass
	3: Color(0.72, 0.55, 0.35), # Wood
	4: Color(0.25, 0.65, 0.18), # Leaves
	5: Color(1.0, 0.45, 0.0),   # Lava
	6: Color(0.92, 0.62, 0.62), # Fried Chicken
	7: Color(0.75, 0.75, 0.80)  # Wooden Sword
}

func _ready() -> void:
	# Fullscreen translucent backdrop wash
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 0.55) # Translucent dark wash
	add_theme_stylebox_override("panel", bg_style)
	
	_setup_workshop_ui()
	_populate_recipes_list()
	_show_empty_details()

func _setup_workshop_ui() -> void:
	# 1. Main Workshop Card (Centered, glassmorphic)
	var main_card := Panel.new()
	main_card.name = "WorkshopCard"
	main_card.custom_minimum_size = Vector2(800, 480)
	main_card.size = Vector2(800, 480)
	main_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Center adjustment
	main_card.offset_left = -400
	main_card.offset_right = 400
	main_card.offset_top = -240
	main_card.offset_bottom = 240
	
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(16)
	card_style.bg_color = Color(0.06, 0.06, 0.08, 0.92) # Solid dark slate
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.35, 0.35, 0.4, 0.4)
	card_style.shadow_size = 15
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	main_card.add_theme_stylebox_override("panel", card_style)
	add_child(main_card)
	
	# Horizontal splitter (Dual-pane layout)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	main_card.add_child(hbox)
	
	# ==================== LEFT PANE: RECIPE CATALOG ====================
	var left_pane := MarginContainer.new()
	left_pane.custom_minimum_size = Vector2(340, 0)
	left_pane.add_theme_constant_override("margin_left", 20)
	left_pane.add_theme_constant_override("margin_top", 20)
	left_pane.add_theme_constant_override("margin_right", 10)
	left_pane.add_theme_constant_override("margin_bottom", 20)
	hbox.add_child(left_pane)
	
	var left_vbox := VBoxContainer.new()
	left_pane.add_child(left_vbox)
	
	var catalog_title := Label.new()
	catalog_title.text = "BLUEPRINT WORKSHOP"
	var ts := LabelSettings.new()
	ts.font_size = 18
	ts.font_color = Color(1.0, 0.85, 0.2) # Gold
	ts.outline_size = 4
	ts.outline_color = Color.BLACK
	catalog_title.label_settings = ts
	left_vbox.add_child(catalog_title)
	
	left_vbox.add_child(_create_spacer(10))
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	_recipes_list = VBoxContainer.new()
	_recipes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_recipes_list)
	
	# ==================== RIGHT PANE: SELECTED RECIPE DETAILS ====================
	_detail_panel = Panel.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.04, 0.04, 0.05, 0.6)
	detail_style.set_corner_radius_all(14)
	detail_style.border_width_left = 1
	detail_style.border_color = Color(0.25, 0.25, 0.3, 0.2)
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	hbox.add_child(_detail_panel)
	
	var right_margin := MarginContainer.new()
	right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 24)
	right_margin.add_theme_constant_override("margin_top", 20)
	right_margin.add_theme_constant_override("margin_right", 24)
	right_margin.add_theme_constant_override("margin_bottom", 20)
	_detail_panel.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_margin.add_child(right_vbox)
	
	# Large Result Title
	_detail_title = Label.new()
	_detail_title.text = "Select a Blueprint"
	var dts := LabelSettings.new()
	dts.font_size = 22
	dts.font_color = Color.WHITE
	dts.outline_size = 4
	dts.outline_color = Color.BLACK
	_detail_title.label_settings = dts
	right_vbox.add_child(_detail_title)
	
	right_vbox.add_child(_create_spacer(14))
	
	# Large Visual 3D-Like Preview Box
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(0, 110)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.1, 0.12, 0.4)
	ps.set_corner_radius_all(10)
	preview_panel.add_theme_stylebox_override("panel", ps)
	right_vbox.add_child(preview_panel)
	
	# Floating Color Icon in the center
	_detail_icon = ColorRect.new()
	_detail_icon.custom_minimum_size = Vector2(45, 45)
	_detail_icon.size = Vector2(45, 45)
	_detail_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_detail_icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	preview_panel.add_child(_detail_icon)
	
	right_vbox.add_child(_create_spacer(14))
	
	# Checklist subtitle
	var req_label := Label.new()
	req_label.text = "REQUIRED MATERIALS:"
	var rls := LabelSettings.new()
	rls.font_size = 11
	rls.font_color = Color(0.65, 0.65, 0.7)
	req_label.label_settings = rls
	right_vbox.add_child(req_label)
	
	right_vbox.add_child(_create_spacer(6))
	
	# Ingredients checklist box
	_detail_requirements_box = VBoxContainer.new()
	_detail_requirements_box.add_theme_constant_override("separation", 6)
	right_vbox.add_child(_detail_requirements_box)
	
	right_vbox.add_child(_create_spacer(20))
	
	# Fabricate Action Button
	_craft_button = Button.new()
	_craft_button.text = "FABRICATE ITEM"
	_craft_button.custom_minimum_size = Vector2(0, 50)
	_craft_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_craft_button.pressed.connect(_on_craft_pressed)
	right_vbox.add_child(_craft_button)
	
	_setup_button_style(_craft_button)

func _populate_recipes_list() -> void:
	for recipe in RecipeRegistry.get_all_recipes():
		var btn := Button.new()
		btn.text = "  " + recipe.recipe_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 42)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Custom normal style for the list cards
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.12, 0.12, 0.15, 0.4)
		sn.set_corner_radius_all(8)
		sn.border_width_left = 4
		sn.border_color = BLOCK_COLORS.get(recipe.output_item_index, Color.DARK_GRAY) # Color-coded strip!
		
		var sh := sn.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.18, 0.18, 0.22, 0.7)
		sh.border_color = Color(1.0, 0.85, 0.2) # Gold hover border
		
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sn)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		
		btn.pressed.connect(func() -> void: _on_recipe_selected(recipe))
		_recipes_list.add_child(btn)

func _show_empty_details() -> void:
	_detail_title.text = "Select a Blueprint"
	_detail_icon.visible = false
	_detail_requirements_box.visible = false
	_craft_button.visible = false

func _on_recipe_selected(recipe: Recipe) -> void:
	_selected_recipe = recipe
	_detail_title.text = recipe.recipe_name.to_upper() + " (x" + str(recipe.output_quantity) + ")"
	
	_detail_icon.color = BLOCK_COLORS.get(recipe.output_item_index, Color.WHITE)
	_detail_icon.visible = true
	_detail_requirements_box.visible = true
	_craft_button.visible = true
	
	_refresh_checklist()

func _refresh_checklist() -> void:
	if _selected_recipe == null or not is_instance_valid(player):
		return
		
	# Clear old checklist cards
	for child in _detail_requirements_box.get_children():
		child.queue_free()
		
	var inventory = player.get("inventory")
	var can_craft_current := CraftingService.can_craft(inventory, _selected_recipe)
	
	# Populate visual ingredient cards
	for slot_index in _selected_recipe.inputs.keys():
		var required_qty := _selected_recipe.inputs[slot_index] as int
		var current_qty := inventory.get_slot_quantity(slot_index) as int
		var item_name := (inventory as InventoryComponent).get_slot_item_name(slot_index)
		
		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, 36)
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.1, 0.1, 0.12, 0.3)
		rs.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", rs)
		_detail_requirements_box.add_child(row)
		
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Checklist logic coloring (Green checkmark if satisfied, Red cross if missing)
		if current_qty >= required_qty:
			label.text = "   ✔  %d / %d  %s" % [current_qty, required_qty, item_name.to_upper()]
			var ls := LabelSettings.new()
			ls.font_size = 13
			ls.font_color = Color(0.25, 0.85, 0.35) # Vibrant Green
			label.label_settings = ls
		else:
			label.text = "   ✘  %d / %d  %s" % [current_qty, required_qty, item_name.to_upper()]
			var ls := LabelSettings.new()
			ls.font_size = 13
			ls.font_color = Color(0.92, 0.15, 0.15) # Red warning
			label.label_settings = ls
			
		row.add_child(label)
		
	# Toggle Craft button interactivity safely
	_craft_button.disabled = not can_craft_current
	if can_craft_current:
		_craft_button.modulate = Color.WHITE
	else:
		_craft_button.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_craft_pressed() -> void:
	if _selected_recipe == null or not is_instance_valid(player):
		return
		
	var inventory = player.get("inventory")
	if CraftingService.craft(inventory, _selected_recipe):
		
		# Play tactile viewmodel swing feedback
		var viewmodel = player.get("viewmodel")
		if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
			viewmodel.call("play_swing_animation")
			
		# Toast notification on HUD
		var hud = player.get("hud")
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "Crafting Success", "Created: " + _selected_recipe.recipe_name + "!")
			
		# Refresh the visual checklist after transaction
		_refresh_checklist()

func _input(event: InputEvent) -> void:
	# Close the panel using C or Escape
	if event.is_action_pressed("craft_item") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

func _setup_button_style(btn: Button) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.55, 0.32, 0.8) # Solid Green Action button
	sn.set_corner_radius_all(10)
	sn.border_width_left = 2
	sn.border_width_top = 2
	sn.border_width_right = 2
	sn.border_width_bottom = 2
	sn.border_color = Color(0.2, 0.8, 0.45, 0.5)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.15, 0.65, 0.38, 1.0) # Highlight Green
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9) # Gold highlighted border when active!
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("disabled", StyleBoxFlat.new()) # Handled in modulate
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 14)

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
