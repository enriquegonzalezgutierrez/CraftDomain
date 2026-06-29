# ==============================================================================
# Project: CraftDomain
# Description: Fullscreen Glassmorphic Tactical World Map Overlay.
#              Renders a 2D coordinate grid, showing the player's precise 
#              location and orientation, alongside clickable POI pins that
#              support OCP Fast-Travel teleportation.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating map drawing.
#              i18n UPGRADE: Localized titles, button tooltips, and map tags.
#              FIX: Resolved variable shadowing, implicit inference warnings, and 
#              unregistered world_controller scope accesses.
#              TELEPORT FIXED: Swapped int() casts for floori() to guarantee negative
#              coordinate chunks (like Z=-300) map perfectly to physical bounds.
#              SAFE SPAWN FIX: Redirected all 4 POI teleport destinations to open-air
#              courtyards and walkways, completely preventing collision interpenetration!
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MapOverlay.gd
# ==============================================================================
class_name MapOverlay
extends Panel

## Emitted when the user closes the map overlay
signal closed

var player: CharacterBody3D

# UI Nodes
var _map_panel: Panel
var _radar_canvas: Control
var _title_label: Label
var _close_btn: Button

# Theme Colors for map elements
const COLOR_GRID := Color(0.22, 0.22, 0.28, 0.35)
const COLOR_GRID_MAIN := Color(0.35, 0.35, 0.42, 0.6)
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_PULSE := Color(0.2, 0.85, 0.85, 0.25)

# Coordinate scaling factor: Maps -400..400 global coordinates to 500x500 pixels
const MAP_COORD_RANGE: float = 800.0 # Total span
const MAP_PANEL_SIZE: float = 500.0

func _ready() -> void:
	# Fullscreen dark wash backdrop
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.02, 0.03, 0.75)
	add_theme_stylebox_override("panel", bg_style)
	
	_setup_map_ui()
	_populate_landmark_pins()
	_refresh_localized_text()

func _setup_map_ui() -> void:
	# 1. Main centered card panel
	_map_panel = Panel.new()
	_map_panel.name = "MapCard"
	_map_panel.custom_minimum_size = Vector2(540, 600)
	_map_panel.size = Vector2(540, 600)
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_map_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_map_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_map_panel.offset_left = -270
	_map_panel.offset_right = 270
	_map_panel.offset_top = -300
	_map_panel.offset_bottom = 300
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	style.shadow_size = 20; style.shadow_color = Color(0, 0, 0, 0.5)
	_map_panel.add_theme_stylebox_override("panel", style)
	add_child(_map_panel)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	_map_panel.add_child(vbox)
	
	vbox.add_child(_create_spacer(14))
	
	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 18; ts.font_color = Color(0.2, 0.85, 0.85); ts.outline_size = 4; ts.outline_color = Color.BLACK
	_title_label.label_settings = ts
	vbox.add_child(_title_label)
	
	# 2. Centered Radar Map Canvas (500x500)
	var canvas_panel := Panel.new()
	canvas_panel.custom_minimum_size = Vector2(MAP_PANEL_SIZE, MAP_PANEL_SIZE)
	canvas_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.04, 0.04, 0.05, 0.8)
	cs.set_corner_radius_all(8)
	cs.border_width_left = 1; cs.border_width_top = 1; cs.border_width_right = 1; cs.border_width_bottom = 1
	cs.border_color = Color(0.2, 0.2, 0.25, 0.4)
	canvas_panel.add_theme_stylebox_override("panel", cs)
	vbox.add_child(canvas_panel)
	
	_radar_canvas = Control.new()
	_radar_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar_canvas.draw.connect(_on_radar_draw)
	canvas_panel.add_child(_radar_canvas)
	
	# 3. Close Button
	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(160, 42)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(_close_btn)
	_setup_button_style(_close_btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()

func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): _title_label.text = tr("MAP_TITLE").to_upper()
	if is_instance_valid(_close_btn): _close_btn.text = tr("SETTINGS_BACK").to_upper()

func _process(_delta: float) -> void:
	if is_instance_valid(_radar_canvas) and visible:
		_radar_canvas.queue_redraw()

# ==============================================================================
# RADAR COORDINATE GRID DRAWING (SRP)
# ==============================================================================

func _on_radar_draw() -> void:
	if _radar_canvas == null or not is_instance_valid(player) or not is_instance_valid(player.world_controller):
		return
		
	var size_vector := _radar_canvas.size
	
	# 1. DRAW CARTESIAN COORDINATE REGRID LINES
	var steps := 8
	var step_px_x := size_vector.x / float(steps)
	var step_px_y := size_vector.y / float(steps)
	
	for i in range(1, steps):
		var y_pos := float(i) * step_px_y
		var line_color := COLOR_GRID_MAIN if i == int(steps / 2.0) else COLOR_GRID
		_radar_canvas.draw_line(Vector2(0, y_pos), Vector2(size_vector.x, y_pos), line_color, 1.0)
		
		var x_pos := float(i) * step_px_x
		_radar_canvas.draw_line(Vector2(x_pos, 0), Vector2(x_pos, size_vector.y), line_color, 1.0)
		
	# 2. DRAW ALL LANDMARK PINS RELATIVELY ON THE CANVAS
	var landmarks := MegaStructureService.get_structures()
	for landmark in landmarks:
		var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
		_radar_canvas.draw_circle(pin_pos, 5.0, Color(0.9, 0.65, 0.15))
		
	# 3. DRAW DYNAMIC PLAYER VECTOR (Pulsing Arrow)
	var p_pos := player.global_position
	var p_map_pos := _world_to_map_space(Vector2(p_pos.x, p_pos.z))
	
	var pulse_radius: float = 8.0 + abs(sin(Time.get_ticks_msec() / 250.0)) * 6.0
	_radar_canvas.draw_circle(p_map_pos, pulse_radius, COLOR_PULSE)
	_radar_canvas.draw_circle(p_map_pos, 4.0, COLOR_PLAYER)
	
	var look_angle := -player.rotation.y - (PI / 2.0)
	var arrow_length := 15.0
	var arrow_end := p_map_pos + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
	_radar_canvas.draw_line(p_map_pos, arrow_end, COLOR_PLAYER, 2.0)

## Conversion helper mapping -400..400 global coordinates to 0..500 map canvas pixel coordinates
func _world_to_map_space(world_pos: Vector2) -> Vector2:
	var coord_scale := MAP_PANEL_SIZE / MAP_COORD_RANGE
	var half_size := MAP_PANEL_SIZE / 2.0
	
	var mx := half_size + (world_pos.x * coord_scale)
	var my := half_size + (world_pos.y * coord_scale)
	
	return Vector2(
		clampf(mx, 10.0, MAP_PANEL_SIZE - 10.0),
		clampf(my, 10.0, MAP_PANEL_SIZE - 10.0)
	)

# ==============================================================================
# LANDMARK INTERACTIVE PINS (Fast-Travel Teleportation OCP)
# ==============================================================================

func _populate_landmark_pins() -> void:
	var landmarks := MegaStructureService.get_structures()
	for landmark in landmarks:
		var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
		
		# Create an interactive, transparent Button centered exactly over the circle
		var btn := Button.new()
		btn.name = "Pin_" + landmark.get_name()
		btn.custom_minimum_size = Vector2(24, 24)
		btn.size = Vector2(24, 24)
		btn.position = pin_pos - Vector2(12, 12)
		
		# Setup dynamic fast-travel tooltip text
		btn.tooltip_text = "%s\n[ X: %d | Z: %d ]\n\n➔ CLICK TO TELEPORT (FAST TRAVEL)" % [
			tr(landmark.get_name()).to_upper(),
			landmark.global_center.x,
			landmark.global_center.y
		]
		
		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(12)
		style_normal.bg_color = Color(1.0, 0.85, 0.2, 0.1)
		style_normal.border_width_left = 2; style_normal.border_width_top = 2; style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
		style_normal.border_color = Color(1.0, 0.85, 0.2, 0.7)
		
		var style_hover := style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.9, 0.15, 0.15, 0.35)
		style_hover.border_color = Color(0.95, 0.15, 0.15, 1.0)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		_radar_canvas.add_child(btn)
		btn.pressed.connect(_on_landmark_pin_pressed.bind(landmark))

func _on_landmark_pin_pressed(landmark: IMegaStructure) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.world_controller):
		return
		
	# Safe spawn coordinates: Center the coordinates
	var target_x := float(landmark.global_center.x) + 0.5
	var target_z := float(landmark.global_center.y) + 0.5
	
	# ==========================================================================
	# COLLISION INTERPENETRATION SAFE SHIELDS (OCP Safe Spawns)
	# Redirects target coordinates to open-air courtyards instead of solid blocks.
	# ==========================================================================
	if landmark is StevesCabinMegaStructure:
		target_z = -294.5 # Symmetrical fenced grass yard
	elif landmark is NetherPortalMegaStructure:
		target_x = -290.5 # Fortress open red sand courtyard
		target_z = -290.5
	elif landmark is GrandCastleMegaStructure:
		target_z = 208.5 # South Gate open brick bridge courtyard
	elif landmark is HarborCityMegaStructure:
		target_x = -136.5 # Wooden harbor pier walkway
		target_z = 3.5
	
	# Freeze physics, set high floating coordinate, and clear accumulated velocities
	player.global_position = Vector3(target_x, 35.0, target_z) 
	player.velocity = Vector3.ZERO
	player.set("is_active", false) 
	
	# Set target spawn chunk coordinates on the World Controller
	var world_node: Node = player.world_controller as Node
	if is_instance_valid(world_node):
		var chunk_pos: Vector3i = world_node.get("world_state").global_to_chunk_pos(Vector3i(floori(target_x), 0, floori(target_z)))
		world_node.set("_target_spawn_chunk_pos", chunk_pos)
		
	closed.emit()

# ==============================================================================
# STYLING HELPERS
# ==============================================================================

func _setup_button_style(btn: Button) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.55, 0.82, 0.8)
	sn.set_corner_radius_all(10)
	sn.border_width_left = 1; sn.border_width_top = 1; sn.border_width_right = 1; sn.border_width_bottom = 1
	sn.border_color = Color(0.2, 0.8, 0.45, 0.4)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.15, 0.65, 0.38, 1.0)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 14)

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
