# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller managing a modern, glassmorphic HUD
#              comprising a perfect circular Minimap with native hardware clipping,
#              a sleek crosshair, and a centered hotbar with selection indicators.
#              Loosely typed to prevent compile-time circular class loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/PlayerHUD.gd
# ==============================================================================
class_name PlayerHUD
extends Control

## Dependencies injected by the parent controller, loosely typed to prevent circular loops
var player: PlayerController
var world_controller: Node3D

# Inner UI nodes created dynamically
var minimap: Control
var inventory_label: Label
var hotbar_slots: Array[Panel] = []

# Hotbar items mapping
const HOTBAR_ITEMS = ["Stone", "Dirt", "Grass", "Wood", "Leaves", "Lava Bucket", "Fried Chicken"]

func _ready() -> void:
	# Stretch HUD to cover the full viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_crosshair()
	_setup_minimap()
	_setup_hotbar()
	_setup_inventory_display()

func _setup_crosshair() -> void:
	# Programmatic center targeting minimalist crosshair (Tiny white plus)
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
	# 1. Circular container with modern dark borders and shadow
	var minimap_bg := Panel.new()
	minimap_bg.name = "MinimapBackground"
	minimap_bg.custom_minimum_size = Vector2(150, 150) # Sized symmetrically
	minimap_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap_bg.offset_left = -170
	minimap_bg.offset_top = 20
	
	# Modern circular border styling with drop shadow
	var style := StyleBoxFlat.new()
	style.corner_detail = 8
	style.set_corner_radius_all(75) # Perfect Circle Panel
	style.bg_color = Color(0.12, 0.12, 0.12, 0.5) # Translucent dark glass
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.25, 0.25, 0.25, 0.8) # Sleek grey rim
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.25) # Soft shadow
	minimap_bg.add_theme_stylebox_override("panel", style)
	
	# Enable native hardware circular clipping of all children nodes added to this panel
	minimap_bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(minimap_bg)
	
	# 2. Draw canvas container for the dynamic radar
	minimap = Control.new()
	minimap.name = "MinimapRadar"
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_bg.add_child(minimap)
	
	# Statically construct the compiled code line-by-line (statically typed assignments used)
	var minimap_script := GDScript.new()
	var code_lines: Array[String] = [
		"extends Control",
		"",
		"var hud: Control",
		"",
		"func _draw() -> void:",
		"\tif not is_instance_valid(hud) or not is_instance_valid(hud.player) or not is_instance_valid(hud.world_controller):",
		"\t\treturn",
		"\tvar size_pixels := size.x",
		"\tvar center := size / 2.0",
		"\tvar radius_limit: float = size_pixels / 2.0 - 5.0",
		"\t# Draw clean background radar circle matching the panel boundaries",
		"\tdraw_circle(center, radius_limit, Color(0.08, 0.08, 0.08, 0.75))",
		"\tvar world_state = hud.world_controller.world_state",
		"\tvar p_block_pos := Vector3i(floor(hud.player.global_position.x), 0, floor(hud.player.global_position.z))",
		"\t# Statically typed assignment to prevent parser type inference errors",
		"\tvar center_chunk_pos: Vector3i = world_state.global_to_chunk_pos(p_block_pos)",
		"\tvar scale_factor: float = (size_pixels - 20) / 5.0",
		"\tfor x in range(-2, 3):",
		"\t\tfor z in range(-2, 3):",
		"\t\t\tvar target_pos := Vector3i(center_chunk_pos.x + x, 0, center_chunk_pos.z + z)",
		"\t\t\tvar chunk = world_state.get_chunk(target_pos)",
		"\t\t\tif chunk == null:",
		"\t\t\t\tcontinue",
		"\t\t\tvar draw_pos := center + Vector2(x, z) * scale_factor - Vector2(scale_factor / 2.0, scale_factor / 2.0)",
		"\t\t\t# Mathematical Clipping: Crop drawing of blocks if they fall outside the radar circle",
		"\t\t\tvar block_center := draw_pos + Vector2(scale_factor / 2.0, scale_factor / 2.0)",
		"\t\t\tif block_center.distance_to(center) > radius_limit:",
		"\t\t\t\tcontinue",
		"\t\t\tvar is_village: bool = (abs(target_pos.x) + abs(target_pos.z)) % 3 == 2",
		"\t\t\tvar chunk_color := Color(0.4, 0.75, 0.3)",
		"\t\t\tif is_village:",
		"\t\t\t\tchunk_color = Color(1.0, 0.45, 0.0)",
		"\t\t\tdraw_rect(Rect2(draw_pos, Vector2(scale_factor - 2, scale_factor - 2)), chunk_color, true)",
		"\tvar arrow_vertices := PackedVector2Array([",
		"\t\tcenter + Vector2(0, -8),",
		"\t\tcenter + Vector2(-5, 6),",
		"\t\tcenter + Vector2(5, 6)",
		"\t])",
		"\tvar angle: float = -hud.player.rotation.y",
		"\tvar rotated_vertices := PackedVector2Array()",
		"\tfor vertex in arrow_vertices:",
		"\t\tvar relative_vec := vertex - center",
		"\t\tvar rotated_vec := relative_vec.rotated(angle)",
		"\t\trotated_vertices.append(center + rotated_vec)",
		"\tdraw_colored_polygon(rotated_vertices, Color(1.0, 0.9, 0.0))"
	]
	
	minimap_script.source_code = "\n".join(code_lines)
	minimap_script.reload()
	minimap.set_script(minimap_script)
	minimap.set("hud", self)

func _setup_hotbar() -> void:
	# 1. Main Hotbar container at the bottom-center
	var hotbar_bg := Panel.new()
	hotbar_bg.name = "HotbarBackground"
	hotbar_bg.custom_minimum_size = Vector2(480, 70)
	hotbar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_bg.offset_bottom = -20
	
	# Stylize hotbar base
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = Color(0.05, 0.05, 0.05, 0.8) # Translucent dark
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	hotbar_bg.add_theme_stylebox_override("panel", style)
	add_child(hotbar_bg)
	
	# 2. Horizontal layout to hold individual item boxes
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_bg.add_child(hbox)
	
	# 3. Create 6 distinct quick-slots programmatically
	for i in range(6):
		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(60, 60)
		
		# Individual slot styling
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(8)
		slot_style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
		slot.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot)
		
		# Item label inside the slot
		var label := Label.new()
		label.name = "ItemLabel"
		label.text = HOTBAR_ITEMS[i].substr(0, 3).to_upper() # First 3 letters
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
		
	# Refresh default highlight
	update_active_slot(0)

func _setup_inventory_display() -> void:
	# Active selection display placed centered directly ABOVE the hotbar panel
	inventory_label = Label.new()
	inventory_label.name = "InventoryLabel"
	inventory_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory_label.offset_bottom = -95 # Positioned cleanly above the Hotbar
	inventory_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style := LabelSettings.new()
	style.font_size = 18
	style.outline_size = 4
	style.outline_color = Color.BLACK
	inventory_label.label_settings = style
	
	add_child(inventory_label)
	_update_inventory_display()

func _process(_delta: float) -> void:
	# Force the minimap drawing system to refresh on every frame
	if is_instance_valid(minimap):
		minimap.queue_redraw()

## Public API to update the highlighted slot on the hotbar dynamically.
func update_active_slot(active_index: int) -> void:
	for i in range(hotbar_slots.size()):
		var slot: Panel = hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		
		if style == null:
			continue
			
		if i == active_index:
			# Highlighted slot: glowing golden border
			style.bg_color = Color(0.25, 0.25, 0.25, 0.8)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(1.0, 0.85, 0.2) # Glowing gold
			
			# Dynamically update the centered text label above the hotbar
			if is_instance_valid(inventory_label):
				inventory_label.text = "[ %s ]" % HOTBAR_ITEMS[i].to_upper()
		else:
			# Inactive slots: standard dim grey borders
			style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.2, 0.4)

func _update_inventory_display() -> void:
	if is_instance_valid(player):
		update_active_slot(0)
