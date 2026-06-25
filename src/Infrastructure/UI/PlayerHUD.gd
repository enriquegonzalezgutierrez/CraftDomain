# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller managing a modern, glassmorphic HUD.
#              Features a perfect circular Minimap utilizing real-time regional
#              biome colors, a target crosshair, centered hotbar, top-left health,
#              and a newly added Top-Center GPS Navigation & Compass card.
#              Fully typed statically inside inline scripts to prevent compile warnings.
#              Uses profile.biome_id to fetch color codes under the OCP design.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/PlayerHUD.gd
# ==============================================================================
class_name PlayerHUD
extends Control

## Dependencies injected by the parent controller
var player: PlayerController
var world_controller: Node3D

# Inner UI nodes created dynamically
var minimap: Control
var inventory_label: Label
var health_label: Label
var hotbar_slots: Array[Panel] = []

# Navigation UI Nodes
var gps_panel: Panel
var gps_coords_label: Label
var gps_biome_label: Label
var compass_directory_label: Label

# Pause & Settings Menu Overlays
var _pause_overlay: Panel
var _settings_overlay: SettingsMenu

# Modern 8-Slot Hotbar items mapping
const HOTBAR_ITEMS = ["Stone", "Dirt", "Grass", "Wood", "Leaves", "Lava", "Chicken", "Sword"]

# Dictionary mapping Biomes to user-friendly Names and UI Colors
const BIOME_UI_DATA = {
	0: {"name": "Bay of Sails (Spawn Ocean)", "color": Color(0.12, 0.55, 0.82)}, # BAY_OF_SAILS
	1: {"name": "Warp Plateau (Mario Steps)", "color": Color(0.38, 0.85, 0.28)}, # WARP_PLATEAU
	2: {"name": "Golden Bazaar (Village Plains)", "color": Color(0.92, 0.85, 0.35)}, # GOLDEN_BAZAAR
	3: {"name": "Craggy Peaks & Caves", "color": Color(0.48, 0.48, 0.48)}, # CRAGGY_MINES
	4: {"name": "Frostbite Glaciers (North Cap)", "color": Color(0.98, 0.98, 0.98)}, # FROSTBITE_GLACIERS
	5: {"name": "Whispering Redwood Forest", "color": Color(0.18, 0.45, 0.15)}, # REDWOOD_FOREST
	6: {"name": "Red Sandstone Canyons", "color": Color(0.85, 0.38, 0.22)}, # RED_BADLANDS
	7: {"name": "Neon ruins (Cyber Ruins)", "color": Color(0.0, 0.85, 0.85)}, # NEON_RUINS
	8: {"name": "Swamp of Sighs (Mist Bay)", "color": Color(0.28, 0.22, 0.15)}, # SWAMP_OF_SIGHS
	9: {"name": "Cloud Kingdom (Floating Isles)", "color": Color(1.0, 1.0, 1.0)}  # CLOUD_KINGDOM
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_crosshair()
	_setup_minimap()
	_setup_hotbar()
	_setup_inventory_display()
	_setup_health_display()
	_setup_navigation_gps_panel() # New commercial UX feature
	_setup_pause_menu()
	
	if is_instance_valid(player) and player.has_method("_sync_hud_counters"):
		player.call("_sync_hud_counters")

func _setup_crosshair() -> void:
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var draw_script := GDScript.new()
	draw_script.source_code = "extends Control\nfunc _draw() -> void:\n\tvar center := get_viewport_rect().size / 2.0\n\tdraw_line(center - Vector2(4, 0), center + Vector2(4, 0), Color(1,1,1,0.8), 2.0)\n\tdraw_line(center - Vector2(0, 4), center + Vector2(0, 4), Color(1,1,1,0.8), 2.0)\n"
	draw_script.reload()
	crosshair.set_script(draw_script)
	add_child(crosshair)

func _setup_minimap() -> void:
	var minimap_bg := Panel.new()
	minimap_bg.name = "MinimapBackground"
	minimap_bg.custom_minimum_size = Vector2(150, 150)
	minimap_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap_bg.offset_left = -170
	minimap_bg.offset_top = 20
	
	var style := StyleBoxFlat.new()
	style.corner_detail = 8
	style.set_corner_radius_all(75) 
	style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.25)
	minimap_bg.add_theme_stylebox_override("panel", style)
	
	minimap_bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(minimap_bg)
	
	minimap = Control.new()
	minimap.name = "MinimapRadar"
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_bg.add_child(minimap)
	
	var minimap_script := GDScript.new()
	var code_lines: Array[String] = [
		"extends Control",
		"",
		"var hud: Control",
		"",
		"func _draw() -> void:",
		"\tif not is_instance_valid(hud) or not is_instance_valid(hud.player) or not is_instance_valid(hud.world_controller):",
		"\t\treturn",
		"\tvar size_dim: float = 150.0",
		"\tvar center: Vector2 = Vector2(size_dim / 2.0, size_dim / 2.0)",
		"\t",
		"\t# Real-time scan of 10 biome quadrants surrounding the player's coordinate",
		"\tvar player_pos: Vector3 = hud.player.global_position",
		"\tvar grid_radius: int = 4",
		"\tvar step_size: float = 16.0",
		"\t",
		"\tfor x in range(-grid_radius, grid_radius + 1):",
		"\t\tfor z in range(-grid_radius, grid_radius + 1):",
		"\t\t\tvar sample_x: int = int(round(player_pos.x)) + (x * 16)",
		"\t\t\tvar sample_z: int = int(round(player_pos.z)) + (z * 16)",
		"\t\t\t",
		"\t\t\t# Query the Domain BiomeService directly for visual color coordination",
		"\t\t\tvar profile = BiomeService.evaluate_coordinate(sample_x, sample_z, hud.world_controller.generator._terrain_noise)",
		"\t\t\t# CRITICAL OCP FIX: Access 'profile.biome_id' instead of the deprecated 'profile.biome'",
		"\t\t\tvar biome_color: Color = hud.BIOME_UI_DATA[profile.biome_id][\"color\"]",
		"\t\t\t",
		"\t\t\t# Offset grid elements to center around the active yellow arrow",
		"\t\t\tvar draw_pos: Vector2 = center + Vector2(float(x), float(z)) * step_size - Vector2(step_size / 2.0, step_size / 2.0)",
		"\t\t\tvar rect_target := Rect2(draw_pos, Vector2(step_size - 1.0, step_size - 1.0))",
		"\t\t\t",
		"\t\t\t# Enforce radial hardware clipping boundaries",
		"\t\t\tif draw_pos.distance_to(center) < size_dim / 2.0 - 5.0:",
		"\t\t\t\tdraw_rect(rect_target, biome_color, true)",
		"\t",
		"\t# 2. Draw yellow navigation arrow pointing dynamically towards camera orientation",
		"\tvar arrow_vertices := PackedVector2Array([",
		"\t\tcenter + Vector2(0, -8),",
		"\t\tcenter + Vector2(-5, 6),",
		"\t\tcenter + Vector2(5, 6)",
		"\t])",
		"\tvar angle: float = -hud.player.rotation.y",
		"\tvar rotated_vertices := PackedVector2Array()",
		"\tfor vertex in arrow_vertices:",
		"\t\tvar relative_vec: Vector2 = vertex - center",
		"\t\tvar rotated_vec: Vector2 = relative_vec.rotated(angle)",
		"\t\trotated_vertices.append(center + rotated_vec)",
		"\tdraw_colored_polygon(rotated_vertices, Color(1.0, 0.85, 0.1))"
	]
	minimap_script.source_code = "\n".join(code_lines)
	minimap_script.reload()
	minimap.set_script(minimap_script)
	minimap.set("hud", self)

func _setup_navigation_gps_panel() -> void:
	gps_panel = Panel.new()
	gps_panel.name = "GPSPanel"
	gps_panel.custom_minimum_size = Vector2(460, 85)
	gps_panel.size = Vector2(460, 85)
	gps_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gps_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	gps_panel.offset_top = 20
	gps_panel.offset_left = -230
	gps_panel.offset_right = 230
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 0.7)
	style.shadow_size = 5
	style.shadow_color = Color(0, 0, 0, 0.3)
	gps_panel.add_theme_stylebox_override("panel", style)
	add_child(gps_panel)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gps_panel.add_child(vbox)
	
	gps_coords_label = Label.new()
	gps_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_coords := LabelSettings.new()
	ls_coords.font_size = 14
	ls_coords.font_color = Color(1.0, 0.85, 0.1)
	ls_coords.outline_size = 3
	ls_coords.outline_color = Color.BLACK
	gps_coords_label.label_settings = ls_coords
	vbox.add_child(gps_coords_label)
	
	gps_biome_label = Label.new()
	gps_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_biome := LabelSettings.new()
	ls_biome.font_size = 15
	ls_biome.font_color = Color(0.9, 0.95, 1.0)
	ls_biome.outline_size = 3
	ls_biome.outline_color = Color.BLACK
	gps_biome_label.label_settings = ls_biome
	vbox.add_child(gps_biome_label)
	
	compass_directory_label = Label.new()
	compass_directory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_compass := LabelSettings.new()
	ls_compass.font_size = 11
	ls_compass.font_color = Color(0.7, 0.8, 0.9)
	ls_compass.outline_size = 2
	ls_compass.outline_color = Color.BLACK
	compass_directory_label.label_settings = ls_compass
	vbox.add_child(compass_directory_label)

func _setup_hotbar() -> void:
	var hotbar_bg := Panel.new()
	hotbar_bg.name = "HotbarBackground"
	hotbar_bg.custom_minimum_size = Vector2(560, 70)
	hotbar_bg.size = Vector2(560, 70)
	
	hotbar_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	
	hotbar_bg.offset_left = -280
	hotbar_bg.offset_right = 280
	hotbar_bg.offset_bottom = -20
	hotbar_bg.offset_top = -90
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	hotbar_bg.add_theme_stylebox_override("panel", style)
	add_child(hotbar_bg)
	
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_bg.add_child(hbox)
	
	for i in range(8):
		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(60, 60)
		
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(8)
		slot_style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
		slot.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot)
		
		var label := Label.new()
		label.name = "ItemLabel"
		label.text = HOTBAR_ITEMS[i].substr(0, 3).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var label_style := LabelSettings.new()
		label_style.font_size = 12
		label_style.outline_size = 3
		label_style.outline_color = Color.BLACK
		label.label_settings = label_style
		slot.add_child(label)
		
		hotbar_slots.append(slot)
		
	update_active_slot(0)

func _setup_inventory_display() -> void:
	inventory_label = Label.new()
	inventory_label.name = "InventoryLabel"
	inventory_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inventory_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inventory_label.offset_bottom = -110
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style := LabelSettings.new()
	style.font_size = 18
	style.outline_size = 4
	style.outline_color = Color.BLACK
	inventory_label.label_settings = style
	add_child(inventory_label)
	_update_inventory_display()

func _setup_health_display() -> void:
	var health_bg := Panel.new()
	health_bg.name = "HealthBackground"
	health_bg.custom_minimum_size = Vector2(160, 45)
	health_bg.size = Vector2(160, 45)
	health_bg.grow_horizontal = Control.GROW_DIRECTION_END
	health_bg.grow_vertical = Control.GROW_DIRECTION_END
	health_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	health_bg.offset_left = 20
	health_bg.offset_top = 20
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.2)
	health_bg.add_theme_stylebox_override("panel", style)
	add_child(health_bg)
	
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	health_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	health_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var label_style := LabelSettings.new()
	label_style.font_size = 18
	label_style.font_color = Color(0.95, 0.15, 0.15)
	label_style.outline_size = 4
	label_style.outline_color = Color.BLACK
	health_label.label_settings = label_style
	
	health_bg.add_child(health_label)
	update_health_display(3)

func _setup_pause_menu() -> void:
	_pause_overlay = Panel.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	_pause_overlay.add_theme_stylebox_override("panel", bg_style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	var title := Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var title_style := LabelSettings.new()
	title_style.font_size = 32
	title_style.font_color = Color(1.0, 0.95, 0.85)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	title.label_settings = title_style
	box.add_child(title)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	
	var resume_btn := Button.new()
	resume_btn.text = "RESUME GAME"
	resume_btn.custom_minimum_size = Vector2(250, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer2)
	
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.custom_minimum_size = Vector2(250, 48)
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer3)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUIT TO MAIN MENU"
	quit_btn.custom_minimum_size = Vector2(250, 48)
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)
	
	_pause_overlay.visible = false
	add_child(_pause_overlay)

func _process(_delta: float) -> void:
	if is_instance_valid(minimap):
		minimap.queue_redraw()
		
	# Synchronize active Navigation & GPS data
	if is_instance_valid(player) and is_instance_valid(world_controller):
		var p_pos := player.global_position
		
		# 1. Update Coordinates
		gps_coords_label.text = "[ X: %d  ·  Y: %d  ·  Z: %d ]" % [int(round(p_pos.x)), int(round(p_pos.y)), int(round(p_pos.z))]
		
		# 2. Query Biome directly to show the current active region name
		var profile = BiomeService.evaluate_coordinate(
			int(round(p_pos.x)), 
			int(round(p_pos.z)), 
			world_controller.generator._terrain_noise
		)
		gps_biome_label.text = "REGION: %s" % BIOME_UI_DATA[profile.biome_id]["name"].to_upper()
		
		# 3. Dynamic directional Directory Compass
		compass_directory_label.text = "[N] Polar Ice: %dm  |  [E] Village Bazaar: %dm  |  [S] Mario Hills: %dm" % [
			int(abs(p_pos.z - (-500.0))),
			int(abs(p_pos.x - 3000.0)),
			int(abs(p_pos.z - 300.0))
		]

func _update_inventory_display() -> void:
	if is_instance_valid(player):
		update_active_slot(0)

func toggle_pause_menu(p_visible: bool) -> void:
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = p_visible
		
	if not p_visible and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toggle_pause_menu(false)

func _on_settings_pressed() -> void:
	_settings_overlay = SettingsMenu.new()
	_settings_overlay.closed.connect(func() -> void:
		if is_instance_valid(_settings_overlay):
			_settings_overlay.queue_free()
	)
	add_child(_settings_overlay)

func _on_quit_pressed() -> void:
	print("[PlayerHUD] Quit requested. Saving progress and returning to menu...")
	if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
		world_controller.call("save_all")
	var bootstrap = get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")

func update_active_slot(active_index: int) -> void:
	for i in range(hotbar_slots.size()):
		var slot: Panel = hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		if style == null:
			continue
			
		if i == active_index:
			style.bg_color = Color(0.25, 0.25, 0.25, 0.8)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(1.0, 0.85, 0.2)
			
			if is_instance_valid(inventory_label):
				inventory_label.text = "[ %s ]" % HOTBAR_ITEMS[i].to_upper()
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.2, 0.4)

func update_slot_quantity(slot_index: int, item_name: String, quantity: int) -> void:
	if slot_index >= 0 and slot_index < hotbar_slots.size():
		var slot: Panel = hotbar_slots[slot_index]
		var label: Label = slot.get_node_or_null("ItemLabel")
		if is_instance_valid(label):
			if quantity < 0:
				label.text = item_name.substr(0, 3).to_upper()
			else:
				label.text = "%s\n(%d)" % [item_name.substr(0, 3).to_upper(), quantity]

func update_health_display(current_hp: int) -> void:
	if is_instance_valid(health_label):
		var hearts_text: String = "HP: "
		for i in range(max(0, current_hp)):
			hearts_text += "❤ "
		health_label.text = hearts_text
