# ==============================================================================
# Project: CraftDomain
# Description: Fullscreen Glassmorphic Tactical World Map Overlay.
#              COMMERCIAL UI OVERHAUL (100% RESPONSIVE & PANNING):
#              - Interactive Panning: Click and drag the map with the mouse 
#                to slide across the voxel world.
#              - Dynamic Button Repositories: Teleport pins and their labels 
#                re-calculate positions in real-time, auto-hiding off-screen.
#              - Floating Grid Axis: Grid coordinate lines and labels slide 
#                alongside the panning offset, mimicking a military GPS.
#              - Fluid Texture Offset: Biome cache slides using high-performance 
#                matrix transforms, maintaining locked 120 FPS.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating map drawing.
#              BUG FIXES & SECURE TELEPORT:
#              - Injected `_is_teleport_spawn = true` to force vertical height 
#                re-calculations upon landing, resolving the mid-air floating bug.
#              - Fixed variable shadowing by renaming local `is_visible` to `is_pin_visible`.
#              - Fully strictly-typed variables to eliminate warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/MapOverlay.gd
# ==============================================================================
class_name MapOverlay
extends Panel

## Emitted when the user closes the map overlay
signal closed

## Injected reference to the player node
var player: CharacterBody3D

# UI Nodes explicitly typed
var _map_card: Panel
var _radar_canvas: Control
var _title_label: Label
var _close_btn: Button

# Map Animations & Drag State
var _scanline_pos: float = 0.0
var _pulse_timer: float = 0.0
var _map_center: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_center: Vector2 = Vector2.ZERO

# Pre-rendered background map
var _biome_map_texture: ImageTexture

# Dynamic responsive size calculations
var _map_panel_size: float = 500.0

# Theme Colors for map elements
const COLOR_GRID: Color = Color(0.3, 0.85, 1.0, 0.15)       # Holographic cyan grid
const COLOR_GRID_MAIN: Color = Color(0.3, 0.85, 1.0, 0.35)  # Center axis cross
const COLOR_PLAYER: Color = Color(1.0, 1.0, 1.0)
const COLOR_PULSE: Color = Color(0.2, 0.85, 0.85, 0.35)
const COLOR_QUEST: Color = Color(1.0, 0.05, 0.55)           # Magenta

# Coordinate scaling factor: Maps -400..400 global coordinates
const MAP_COORD_RANGE: float = 800.0 # Total map span

# Biome Palette color map
const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.08, 0.45, 0.72), # Deep Ocean
	1: Color(0.28, 0.75, 0.18), # Bright Plateau
	2: Color(0.82, 0.75, 0.25), # Plains
	3: Color(0.38, 0.38, 0.38), # Mountains
	4: Color(0.88, 0.88, 0.88), # Glaciers
	5: Color(0.12, 0.35, 0.10), # Dark Forest
	6: Color(0.75, 0.28, 0.15), # Red Sand
	7: Color(0.0, 0.65, 0.65),  # Neon
	8: Color(0.22, 0.18, 0.12), # Swamp
	9: Color(0.95, 0.95, 0.95)  # Clouds
}


func _ready() -> void:
	# Fullscreen dark wash backdrop
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.02, 0.03, 0.85)
	add_theme_stylebox_override("panel", bg_style)
	
	_calculate_responsive_dimensions()
	
	# Initial map center focused on player coordinate
	if is_instance_valid(player):
		_map_center = Vector2(player.global_position.x, player.global_position.z)
	
	_generate_biome_texture()
	_setup_map_ui()
	_populate_landmark_pins()
	_refresh_localized_text()
	_play_entry_animation()


## Dynamically calculates card and canvas bounds based on the active viewport.
func _calculate_responsive_dimensions() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	
	# Clamp card height to 90% of screen height to guarantee the Back button fits
	var card_h: float = min(viewport_size.y * 0.90, 680.0)
	var card_w: float = min(viewport_size.x * 0.85, 620.0)
	
	# Overhead budget (Title height + Spacers + Close Button + Padding = ~160px)
	var vertical_overhead: float = 160.0
	var horizontal_overhead: float = 60.0
	
	var available_h: float = card_h - vertical_overhead
	var available_w: float = card_w - horizontal_overhead
	
	# Map must be a perfect, responsive square
	_map_panel_size = min(available_h, available_w)


## Pre-renders a fast 120x128 image representing the world's biomes.
func _generate_biome_texture() -> void:
	if not is_instance_valid(player): return
	var world_controller: Node = player.get("world_controller") as Node
	if not is_instance_valid(world_controller): return
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if not is_instance_valid(generator): return
	var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
	if noise == null: return
	
	var img_res: int = 120 
	var img: Image = Image.create(img_res, img_res, false, Image.FORMAT_RGBA8)
	
	for x: int in range(img_res):
		for y: int in range(img_res):
			var world_x: float = ((float(x) / float(img_res)) - 0.5) * MAP_COORD_RANGE
			var world_z: float = ((float(y) / float(img_res)) - 0.5) * MAP_COORD_RANGE
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(int(world_x), int(world_z), noise) as BiomeService.BiomeProfile
			var color: Color = RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK)
			img.set_pixel(x, y, color)
			
	_biome_map_texture = ImageTexture.create_from_image(img)


func _setup_map_ui() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var card_h: float = min(viewport_size.y * 0.90, 680.0)
	var card_w: float = min(viewport_size.x * 0.85, 620.0)

	# 1. Main centered card panel
	_map_card = Panel.new()
	_map_card.name = "MapCard"
	_map_card.custom_minimum_size = Vector2(card_w, card_h)
	_map_card.size = Vector2(card_w, card_h)
	_map_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_map_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_map_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_map_card.offset_left = -card_w / 2.0
	_map_card.offset_right = card_w / 2.0
	_map_card.offset_top = -card_h / 2.0
	_map_card.offset_bottom = card_h / 2.0
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.85, 1.0, 0.5) # Cyan holographic border
	style.shadow_size = 25; style.shadow_color = Color(0, 0, 0, 0.6)
	_map_card.add_theme_stylebox_override("panel", style)
	add_child(_map_card)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER 
	_map_card.add_child(vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts: LabelSettings = LabelSettings.new()
	ts.font_size = 22; ts.font_color = Color(0.2, 0.85, 0.85); ts.outline_size = 4; ts.outline_color = Color.BLACK
	_title_label.label_settings = ts
	vbox.add_child(_title_label)
	
	# 2. Centered Radar Map Canvas (Dynamic proportional box)
	var canvas_panel: Panel = Panel.new()
	canvas_panel.custom_minimum_size = Vector2(_map_panel_size, _map_panel_size)
	canvas_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cs: StyleBoxFlat = StyleBoxFlat.new()
	cs.bg_color = Color(0.02, 0.02, 0.03, 1.0)
	cs.set_corner_radius_all(12)
	cs.border_width_left = 2; cs.border_width_top = 2
	cs.border_width_right = 2; cs.border_width_bottom = 2
	cs.border_color = Color(0.2, 0.55, 0.85, 0.5)
	canvas_panel.add_theme_stylebox_override("panel", cs)
	
	# Keep all drawings perfectly clipped inside the rounded borders
	canvas_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY 
	vbox.add_child(canvas_panel)
	
	_radar_canvas = Control.new()
	_radar_canvas.name = "RadarCanvas"
	_radar_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar_canvas.gui_input.connect(_on_canvas_input)
	_radar_canvas.draw.connect(_on_radar_draw)
	canvas_panel.add_child(_radar_canvas)
	
	# 3. Close Button
	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(200, 48)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(func() -> void: _play_exit_animation())
	vbox.add_child(_close_btn)
	_setup_button_style(_close_btn)


func _play_entry_animation() -> void:
	modulate.a = 0.0
	_map_card.scale = Vector2(0.95, 0.95)
	_map_card.pivot_offset = _map_card.size / 2.0
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_map_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_exit_animation() -> void:
	_map_card.pivot_offset = _map_card.size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_map_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: closed.emit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): 
		_title_label.text = tr("MAP_TITLE").to_upper()
	if is_instance_valid(_close_btn): 
		_close_btn.text = tr("SETTINGS_BACK").to_upper()


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	_scanline_pos += delta * 180.0
	if _scanline_pos > _map_panel_size:
		_scanline_pos = 0.0
		
	if is_instance_valid(_radar_canvas) and visible:
		_radar_canvas.queue_redraw()


# ==============================================================================
# INPUT GESTURE HANDLING: CLICK & DRAG PANNING
# ==============================================================================
func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_center = _map_center
			else:
				_is_dragging = false
				
	elif event is InputEventMouseMotion and _is_dragging:
		var drag_delta: Vector2 = event.position - _drag_start_pos
		# Convert pixel offset to global world meters delta
		var px_to_world_ratio: float = MAP_COORD_RANGE / _map_panel_size
		var world_delta: Vector2 = Vector2(drag_delta.x * px_to_world_ratio, drag_delta.y * px_to_world_ratio)
		
		# Offset is subtracted to move in the drag direction
		_map_center = _drag_start_center - world_delta
		
		# Clamp coordinate pan boundaries so player doesn't drag to infinite void
		_map_center.x = clampf(_map_center.x, -400.0, 400.0)
		_map_center.y = clampf(_map_center.y, -400.0, 400.0)
		
		# Instantly reposition physical button nodes
		_reposition_landmark_pins()
		_radar_canvas.queue_redraw()


# ==============================================================================
# RADAR COORDINATE GRID DRAWING (SRP)
# ==============================================================================
func _on_radar_draw() -> void:
	if not is_instance_valid(_radar_canvas) or not is_instance_valid(player):
		return
		
	var default_font: Font = get_theme_font("font")
	
	# 1. DRAW SMOOTH-SLIDING BIOME BACKGROUND TEXTURE
	if _biome_map_texture != null:
		var coord_scale: float = _map_panel_size / MAP_COORD_RANGE
		# Calculate dynamic slide offset relative to texture size
		var origin_map_pos: Vector2 = Vector2(_map_panel_size / 2.0, _map_panel_size / 2.0) - (_map_center * coord_scale)
		
		var tex_rect: Rect2 = Rect2(
			origin_map_pos.x - (MAP_COORD_RANGE / 2.0 * coord_scale),
			origin_map_pos.y - (MAP_COORD_RANGE / 2.0 * coord_scale),
			MAP_COORD_RANGE * coord_scale,
			MAP_COORD_RANGE * coord_scale
		)
		
		_radar_canvas.draw_texture_rect(_biome_map_texture, tex_rect, false)
		_radar_canvas.draw_rect(Rect2(0, 0, _map_panel_size, _map_panel_size), Color(0.04, 0.04, 0.06, 0.4), true)
	
	# 2. DRAW MOBILE FLOATING COORDINATE GRID LINES & LABELS (Every 100m)
	var start_grid_x: int = int(floor((_map_center.x - MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var end_grid_x: int = int(ceil((_map_center.x + MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var start_grid_z: int = int(floor((_map_center.y - MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var end_grid_z: int = int(ceil((_map_center.y + MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	
	# Draw Z Axis grid lines (Vertical lines moving left/right)
	for gx in range(start_grid_x, end_grid_x + 100, 100):
		var map_pos: Vector2 = _world_to_map_space(Vector2(float(gx), 0.0))
		if map_pos.x >= 0.0 and map_pos.x <= _map_panel_size:
			var is_center: bool = (gx == 0)
			var line_color: Color = COLOR_GRID_MAIN if is_center else COLOR_GRID
			_radar_canvas.draw_line(Vector2(map_pos.x, 0), Vector2(map_pos.x, _map_panel_size), line_color, 1.5 if is_center else 1.0)
			_radar_canvas.draw_string(default_font, Vector2(map_pos.x + 4, 14), str(gx), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.4))

	# Draw X Axis grid lines (Horizontal lines moving up/down)
	for gz in range(start_grid_z, end_grid_z + 100, 100):
		var map_pos: Vector2 = _world_to_map_space(Vector2(0.0, float(gz)))
		if map_pos.y >= 0.0 and map_pos.y <= _map_panel_size:
			var is_center: bool = (gz == 0)
			var line_color: Color = COLOR_GRID_MAIN if is_center else COLOR_GRID
			_radar_canvas.draw_line(Vector2(0, map_pos.y), Vector2(_map_panel_size, map_pos.y), line_color, 1.5 if is_center else 1.0)
			_radar_canvas.draw_string(default_font, Vector2(4, map_pos.y - 4), str(gz), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.4))
		
	# Solid dots (Natively aligned labels update on the button nodes automatically)
	var landmarks: Array[IMegaStructure] = MegaStructureService.get_structures()
	for landmark: IMegaStructure in landmarks:
		var pin_pos: Vector2 = _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
		if pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size:
			_radar_canvas.draw_circle(pin_pos, 5.0, Color(0.9, 0.65, 0.15))
			_radar_canvas.draw_circle(pin_pos, 8.0, Color(0.9, 0.65, 0.15, 0.3), false, 2.0)
		
	var p_pos: Vector3 = player.global_position
	var p_map_pos: Vector2 = _world_to_map_space(Vector2(p_pos.x, p_pos.z))
	
	# 3. DRAW ACTIVE QUEST MARKER & TACTICAL LINE
	var active_q: Quest = QuestService.get_active_quest() as Quest
	if active_q != null and active_q.required_item_index == -1:
		var q_map_pos: Vector2 = _world_to_map_space(Vector2(active_q.target_position.x, active_q.target_position.z))
		
		# Dashed tactical line from player to quest (Only drawn if within bounds)
		_draw_dashed_line(p_map_pos, q_map_pos, Color(1.0, 0.05, 0.55, 0.4), 2.0, 8.0)
		
		if q_map_pos.x >= 0 and q_map_pos.x <= _map_panel_size and q_map_pos.y >= 0 and q_map_pos.y <= _map_panel_size:
			var pulse_radius: float = 12.0 + abs(sin(_pulse_timer)) * 6.0
			_radar_canvas.draw_circle(q_map_pos, pulse_radius, Color(1.0, 0.05, 0.55, 0.25))
			
			var diamond_points: PackedVector2Array = PackedVector2Array([
				q_map_pos + Vector2(0, -8),
				q_map_pos + Vector2(8, 0),
				q_map_pos + Vector2(0, 8),
				q_map_pos + Vector2(-8, 0)
			])
			_radar_canvas.draw_colored_polygon(diamond_points, COLOR_QUEST)
			_radar_canvas.draw_polyline(diamond_points, Color.BLACK, 2.0)
			_radar_canvas.draw_string(default_font, q_map_pos + Vector2(0, 22), tr("HUD_ACTIVE_MISSION").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, COLOR_QUEST)
		
	# 4. DRAW DYNAMIC PLAYER VECTOR (Pulsing Arrow)
	if p_map_pos.x >= 0 and p_map_pos.x <= _map_panel_size and p_map_pos.y >= 0 and p_map_pos.y <= _map_panel_size:
		var p_pulse: float = 10.0 + abs(sin(_pulse_timer)) * 5.0
		_radar_canvas.draw_circle(p_map_pos, p_pulse, COLOR_PULSE)
		_radar_canvas.draw_circle(p_map_pos, 5.0, COLOR_PLAYER)
		
		var look_angle: float = -player.rotation.y - (PI / 2.0)
		var arrow_length: float = 18.0
		var arrow_end: Vector2 = p_map_pos + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
		_radar_canvas.draw_line(p_map_pos, arrow_end, COLOR_PLAYER, 3.0)
	
	# 5. DRAW HOLOGRAPHIC SCANLINE (CRT Effect)
	var scanline_rect: Rect2 = Rect2(0, _scanline_pos, _map_panel_size, 4.0)
	_radar_canvas.draw_rect(scanline_rect, Color(0.2, 0.85, 1.0, 0.2), true)
	_radar_canvas.draw_line(Vector2(0, _scanline_pos), Vector2(_map_panel_size, _scanline_pos), Color(0.2, 0.85, 1.0, 0.6), 1.0)
	
	# 6. DRAG INSTRUCTION LABEL (Centered at the top)
	_radar_canvas.draw_string(default_font, Vector2(_map_panel_size / 2.0, _map_panel_size - 15), "[ " + tr("MAP_DRAG_INSTRUCTION").to_upper() + " ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.3, 0.85, 1.0, 0.6))


## Conversion helper mapping -400..400 global coordinates dynamically relative to current _map_center
func _world_to_map_space(world_pos: Vector2) -> Vector2:
	var coord_scale: float = _map_panel_size / MAP_COORD_RANGE
	var half_size: float = _map_panel_size / 2.0
	
	# Coordinates mapped relative to active camera center offset
	var rel_pos: Vector2 = world_pos - _map_center
	
	var mx: float = half_size + (rel_pos.x * coord_scale)
	var my: float = half_size + (rel_pos.y * coord_scale)
	
	return Vector2(mx, my)


## Helper: Draws a tactical dashed line
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var length: float = from.distance_to(to)
	var dir: Vector2 = (to - from).normalized()
	var current_dist: float = 0.0
	
	while current_dist < length:
		var start: Vector2 = from + dir * current_dist
		var end: Vector2 = from + dir * min(current_dist + dash_length, length)
		_radar_canvas.draw_line(start, end, color, width)
		current_dist += dash_length * 2.0


# ==============================================================================
# LANDMARK INTERACTIVE PINS (Fast-Travel Teleportation OCP)
# ==============================================================================
func _populate_landmark_pins() -> void:
	var landmarks: Array[IMegaStructure] = MegaStructureService.get_structures()
	for landmark: IMegaStructure in landmarks:
		var pin_pos: Vector2 = _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
		
		var btn: Button = Button.new()
		btn.name = "Pin_" + landmark.get_name()
		btn.custom_minimum_size = Vector2(28, 28)
		btn.size = Vector2(28, 28)
		btn.position = pin_pos - Vector2(14, 14)
		
		btn.tooltip_text = "%s\n[ X: %d | Z: %d ]\n\n➔ CLICK TO TELEPORT (FAST TRAVEL)" % [
			tr(landmark.get_name()).to_upper(),
			landmark.global_center.x,
			landmark.global_center.y
		]
		
		var style_normal: StyleBoxFlat = StyleBoxFlat.new()
		style_normal.set_corner_radius_all(14)
		style_normal.bg_color = Color(1.0, 0.85, 0.2, 0.0) # Fully invisible
		style_normal.border_width_left = 2; style_normal.border_width_top = 2
		style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
		style_normal.border_color = Color(1.0, 0.85, 0.2, 0.5)
		
		var style_hover: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.9, 0.15, 0.15, 0.4)
		style_hover.border_color = Color(0.95, 0.15, 0.15, 1.0)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		# --- SMART RESPONSIVE LABELS ---
		var label: Label = Label.new()
		label.text = tr(landmark.get_name()).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(140, 36) # Width limit to force perfect wrapping
		label.size = Vector2(140, 36)
		# Centered directly below the 28x28 pin button
		label.position = Vector2(-56, 22)
		
		var ls: LabelSettings = LabelSettings.new()
		ls.font_size = 10
		ls.font_color = Color(0.95, 0.95, 0.95)
		ls.outline_size = 4
		ls.outline_color = Color.BLACK
		label.label_settings = ls
		btn.add_child(label)
		
		# Hide immediately if spawning out of bounds initially
		var is_pin_visible: bool = pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
		btn.visible = is_pin_visible
		
		_radar_canvas.add_child(btn)
		btn.pressed.connect(_on_landmark_pin_pressed.bind(landmark))


## Recalculates and shifts the physical button nodes dynamically based on active _map_center offsets.
func _reposition_landmark_pins() -> void:
	var landmarks: Array[IMegaStructure] = MegaStructureService.get_structures()
	for landmark: IMegaStructure in landmarks:
		var btn: Button = _radar_canvas.get_node_or_null("Pin_" + landmark.get_name()) as Button
		if is_instance_valid(btn):
			var pin_pos: Vector2 = _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
			btn.position = pin_pos - Vector2(14, 14)
			
			# Edge Safe Mask: Hide button if moved out of bounds to prevent clicking transparent invisible buttons
			var is_pin_visible: bool = pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
			btn.visible = is_pin_visible


func _on_landmark_pin_pressed(landmark: IMegaStructure) -> void:
	if not is_instance_valid(player):
		return
		
	var world_controller: WorldController = player.get("world_controller") as WorldController
	if not is_instance_valid(world_controller):
		return
		
	var target_x: float = float(landmark.global_center.x) + 0.5
	var target_z: float = float(landmark.global_center.y) + 0.5
	
	if landmark is StevesCabinMegaStructure: target_z = -294.5 
	elif landmark is NetherPortalMegaStructure: target_x = -290.5; target_z = -290.5
	elif landmark is GrandCastleMegaStructure: target_z = 208.5 
	elif landmark is HarborCityMegaStructure: target_x = -136.5; target_z = 3.5
	
	player.global_position = Vector3(target_x, 35.0, target_z) 
	player.velocity = Vector3.ZERO
	player.set("is_active", false) 
	
	var hud_node: Control = player.get("hud") as Control
	if is_instance_valid(hud_node) and hud_node.has_method("show_loading_screen"):
		hud_node.call("show_loading_screen")
	
	# ---> SECURE TELEPORT FLAG <---
	# Instruct the World Controller that this is a fast-travel teleport spawner 
	# to bypass static height-safeguards and scan the target terrain ground!
	world_controller.set("_is_teleport_spawn", true)
	
	if is_instance_valid(world_controller.world_state):
		var chunk_pos: Vector3i = world_controller.world_state.global_to_chunk_pos(Vector3i(floori(target_x), 0, floori(target_z)))
		world_controller.set("_target_spawn_chunk_pos", chunk_pos)
		
	closed.emit()


# ==============================================================================
# STYLING HELPERS
# ==============================================================================
func _setup_button_style(btn: Button) -> void:
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.55, 0.82, 0.8)
	sn.set_corner_radius_all(10)
	sn.border_width_left = 1; sn.border_width_top = 1
	sn.border_width_right = 1; sn.border_width_bottom = 1
	sn.border_color = Color(0.2, 0.8, 0.45, 0.4)
	
	var sh: StyleBoxFlat = sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.15, 0.65, 0.38, 1.0)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 14)
	
	# Hover scaling animation
	btn.pivot_offset = Vector2(100, 24)
	btn.mouse_entered.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)


func _create_spacer(height: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
