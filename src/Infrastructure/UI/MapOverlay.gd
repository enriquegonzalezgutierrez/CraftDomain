# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/MapOverlay.gd
# Description: Infrastructure Coordinator strictly managing Tactical World Map
#              projections, click-and-drag panning, and fast-travel teleportation.
#              Layout and structural offsets are strictly defined in .tscn.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively UI mouse dragging,
#   pins placements, and teleportation coordination.
# - Open-Closed Principle (OCP): Closed for modifications. Reads structural positions 
#   polymorphically from IMegaStructure instances.
# - UX Optimization: Instantiates the loading screen instantly on teleport request,
#   yielding a frame to ensure the overlay renders before chunk calculations begin.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MapOverlay
extends Panel

signal closed

@export var player: CharacterBody3D

@onready var _map_card: Panel = $MapCard
@onready var _radar_canvas: Control = $MapCard/VBoxContainer/CanvasPanel/RadarCanvas
@onready var _title_label: Label = $MapCard/VBoxContainer/TitleLabel
@onready var _close_btn: Button = $MapCard/VBoxContainer/CloseButton

# Map Animations & Drag State
var _scanline_pos: float = 0.0
var _pulse_timer: float = 0.0
var _map_center: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_center: Vector2 = Vector2.ZERO

# Pre-rendered background map
var _biome_map_texture: ImageTexture
var _map_panel_size: float = 380.0

# Coordinate scaling factor: Maps -400..400 global coordinates
const MAP_COORD_RANGE: float = 800.0

# Theme Colors for map elements
const COLOR_GRID := Color(0.3, 0.85, 1.0, 0.15)       # Holographic cyan grid
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_PULSE := Color(0.2, 0.85, 0.85, 0.35)
const COLOR_QUEST := Color(1.0, 0.05, 0.55)           # Magenta

# Biome Palette color map
const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.08, 0.45, 0.72), # Deep Ocean
	1: Color(0.28, 0.75, 0.18), # Bright Plateau
	2: Color(0.82, 0.75, 0.25), # Plains
	3: Color(0.38, 0.38, 0.38), # Mountains
	4: Color(0.98, 0.98, 0.98), # Glaciers
	5: Color(0.18, 0.45, 0.15), # Dark Forest
	6: Color(0.85, 0.38, 0.22), # Red Sand
	7: Color(0.0, 0.65, 0.65),  # Neon Ruins
	8: Color(0.22, 0.18, 0.12), # Swamp
	9: Color(0.95, 0.95, 0.95)  # Clouds
}


func _ready() -> void:
	if is_instance_valid(player):
		_map_center = Vector2(player.global_position.x, player.global_position.z)
		
	_generate_biome_texture()
	_populate_landmark_pins()
	_refresh_localized_text()
	_play_entry_animation()
	
	_radar_canvas.gui_input.connect(_on_canvas_input)
	_radar_canvas.draw.connect(_on_radar_draw)
	_close_btn.pressed.connect(_play_exit_animation)


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	_scanline_pos += delta * 180.0
	if _scanline_pos > _map_panel_size:
		_scanline_pos = 0.0
		
	if is_instance_valid(_radar_canvas) and visible:
		_radar_canvas.queue_redraw()


func _play_entry_animation() -> void:
	modulate.a = 0.0
	_map_card.scale = Vector2(0.95, 0.95)
	_map_card.pivot_offset = _map_card.size / 2.0
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_map_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_exit_animation() -> void:
	_map_card.pivot_offset = _map_card.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_map_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: closed.emit())


func _refresh_localized_text() -> void:
	if is_instance_valid(_title_label): 
		_title_label.text = tr("MAP_TITLE").to_upper()
	if is_instance_valid(_close_btn): 
		_close_btn.text = tr("SETTINGS_BACK").to_upper()


func _generate_biome_texture() -> void:
	var p_ctrl := player as PlayerController
	if not is_instance_valid(p_ctrl): 
		return
		
	var world_ctrl := p_ctrl.world_controller as WorldController
	if not is_instance_valid(world_ctrl): 
		return
		
	var generator_node := world_ctrl.generator as WorldGenerator
	if not is_instance_valid(generator_node): 
		return
		
	var noise := generator_node.get("_terrain_noise") as FastNoiseLite
	if noise == null: 
		return
	
	var img_res: int = 120 
	var img := Image.create(img_res, img_res, false, Image.FORMAT_RGBA8)
	
	for x: int in range(img_res):
		for y: int in range(img_res):
			var world_x: float = ((float(x) / float(img_res)) - 0.5) * MAP_COORD_RANGE
			var world_z: float = ((float(y) / float(img_res)) - 0.5) * MAP_COORD_RANGE
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(int(world_x), int(world_z), noise) as BiomeService.BiomeProfile
			var color := RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK) as Color
			img.set_pixel(x, y, color)
			
	_biome_map_texture = ImageTexture.create_from_image(img)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_click := event as InputEventMouseButton
		if mouse_click.button_index == MOUSE_BUTTON_LEFT:
			if mouse_click.pressed:
				_is_dragging = true
				_drag_start_pos = mouse_click.position
				_drag_start_center = _map_center
			else:
				_is_dragging = false
				
	elif event is InputEventMouseMotion and _is_dragging:
		var mouse_motion := event as InputEventMouseMotion
		var drag_delta: Vector2 = mouse_motion.position - _drag_start_pos
		var px_to_world_ratio := MAP_COORD_RANGE / _map_panel_size
		var world_delta := Vector2(drag_delta.x * px_to_world_ratio, drag_delta.y * px_to_world_ratio)
		
		_map_center = _drag_start_center - world_delta
		_map_center.x = clampf(_map_center.x, -400.0, 400.0)
		_map_center.y = clampf(_map_center.y, -400.0, 400.0)
		
		_reposition_landmark_pins()
		_radar_canvas.queue_redraw()


func _on_radar_draw() -> void:
	if not is_instance_valid(_radar_canvas) or not is_instance_valid(player):
		return
		
	var default_font: Font = get_theme_font("font")
	var p_pos: Vector3 = player.global_position
	var p_map_pos := _world_to_map_space(Vector2(p_pos.x, p_pos.z))
	
	# 1. DRAW BIOME BACKGROUND
	if _biome_map_texture != null:
		var coord_scale := _map_panel_size / MAP_COORD_RANGE
		var origin_map_pos := Vector2(_map_panel_size / 2.0, _map_panel_size / 2.0) - (_map_center * coord_scale)
		var tex_rect := Rect2(
			origin_map_pos.x - (MAP_COORD_RANGE / 2.0 * coord_scale),
			origin_map_pos.y - (MAP_COORD_RANGE / 2.0 * coord_scale),
			MAP_COORD_RANGE * coord_scale,
			MAP_COORD_RANGE * coord_scale
		)
		_radar_canvas.draw_texture_rect(_biome_map_texture, tex_rect, false)
		_radar_canvas.draw_rect(Rect2(0, 0, _map_panel_size, _map_panel_size), Color(0.04, 0.04, 0.06, 0.4), true)
	
	# 2. DRAW COORDINATE GRID
	var start_grid_x := int(floor((_map_center.x - MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var end_grid_x := int(ceil((_map_center.x + MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var start_grid_z := int(floor((_map_center.y - MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	var end_grid_z := int(ceil((_map_center.y + MAP_COORD_RANGE / 2.0) / 100.0) * 100.0)
	
	for gx in range(start_grid_x, end_grid_x + 100, 100):
		var s_pos := _world_to_map_space(Vector2(float(gx), 0.0))
		if s_pos.x >= 0.0 and s_pos.x <= _map_panel_size:
			_radar_canvas.draw_line(Vector2(s_pos.x, 0), Vector2(s_pos.x, _map_panel_size), COLOR_GRID)
			_radar_canvas.draw_string(default_font, Vector2(s_pos.x + 4, _map_panel_size - 6), str(gx), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID * 2.0)
	
	for gz in range(start_grid_z, end_grid_z + 100, 100):
		var s_pos := _world_to_map_space(Vector2(0.0, float(gz)))
		if s_pos.y >= 0.0 and s_pos.y <= _map_panel_size:
			_radar_canvas.draw_line(Vector2(0, s_pos.y), Vector2(_map_panel_size, s_pos.y), COLOR_GRID)
			_radar_canvas.draw_string(default_font, Vector2(6, s_pos.y - 4), str(gz), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID * 2.0)

	# 3. DRAW ACTIVE QUEST MARKER
	var active_q := QuestService.get_active_quest() as Quest
	if active_q != null and active_q.target_position != Vector3.ZERO:
		var q_pos := Vector2(active_q.target_position.x, active_q.target_position.z)
		var draw_target := _world_to_map_space(q_pos)
		
		var pulse_radius: float = 10.0 + abs(sin(_pulse_timer * 1.5)) * 6.0
		_radar_canvas.draw_circle(draw_target, pulse_radius, Color(COLOR_QUEST.r, COLOR_QUEST.g, COLOR_QUEST.b, 0.22))
		
		var diamond_points := PackedVector2Array([
			draw_target + Vector2(0, -8),
			draw_target + Vector2(8, 0),
			draw_target + Vector2(0, 8),
			draw_target + Vector2(-8, 0)
		])
		_radar_canvas.draw_colored_polygon(diamond_points, COLOR_QUEST)
		_radar_canvas.draw_polyline(diamond_points, Color.BLACK, 2.0)
		_draw_dashed_line(p_map_pos, draw_target, Color(COLOR_QUEST.r, COLOR_QUEST.g, COLOR_QUEST.b, 0.55), 2.5, 10.0)

	# 4. DRAW PLAYER ARROW
	if p_map_pos.x >= 0 and p_map_pos.x <= _map_panel_size and p_map_pos.y >= 0 and p_map_pos.y <= _map_panel_size:
		var p_pulse: float = 12.0 + abs(sin(_pulse_timer)) * 6.0
		_radar_canvas.draw_circle(p_map_pos, p_pulse, COLOR_PULSE)
		_radar_canvas.draw_circle(p_map_pos, 4.0, Color.BLACK)
		_radar_canvas.draw_circle(p_map_pos, 3.0, COLOR_PLAYER)
		
		var look_angle := -player.rotation.y - (PI / 2.0)
		var arrow_length := 22.0
		var arrow_end := p_map_pos + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
		
		_radar_canvas.draw_line(p_map_pos, arrow_end, Color.BLACK, 4.0)
		_radar_canvas.draw_line(p_map_pos, arrow_end, COLOR_PLAYER, 2.0)


func _world_to_map_space(world_pos: Vector2) -> Vector2:
	var coord_scale := _map_panel_size / MAP_COORD_RANGE
	var half_size := _map_panel_size / 2.0
	var rel_pos := world_pos - _map_center
	return Vector2(half_size + (rel_pos.x * coord_scale), half_size + (rel_pos.y * coord_scale))


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var current_dist := 0.0
	
	while current_dist < length:
		var start := from + dir * current_dist
		var step_limit := minf(current_dist + dash_length, length)
		var end := from + dir * step_limit
		_radar_canvas.draw_line(start, end, color, width)
		current_dist += dash_length * 2.0


# ==============================================================================
# LANDMARK TELEPORT PINS (OCP)
# ==============================================================================

func _populate_landmark_pins() -> void:
	var landmarks := MegaStructureService.get_structures()
	for landmark: IMegaStructure in landmarks:
		var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
		
		var btn := Button.new()
		btn.name = "Pin_" + landmark.get_name()
		btn.custom_minimum_size = Vector2(28, 28)
		btn.size = Vector2(28, 28)
		btn.position = pin_pos - Vector2(14, 14)
		
		btn.tooltip_text = tr("MAP_TELEPORT_TOOLTIP") % [
			tr(landmark.get_name()).to_upper(),
			landmark.global_center.x,
			landmark.global_center.y
		]
		
		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(14)
		style_normal.bg_color = Color(1.0, 0.85, 0.2, 0.0)
		style_normal.border_width_left = 2; style_normal.border_width_top = 2
		style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
		style_normal.border_color = Color(1.0, 0.85, 0.2, 0.5)
		
		var style_hover := style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.9, 0.15, 0.15, 0.4)
		style_hover.border_color = Color(0.95, 0.15, 0.15, 1.0)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var label := Label.new()
		label.text = tr(landmark.get_name()).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(140, 36)
		label.size = Vector2(140, 36)
		label.position = Vector2(-56, 22)
		
		var ls := LabelSettings.new()
		ls.font_size = 10
		ls.font_color = Color(0.95, 0.95, 0.95)
		ls.outline_size = 4
		ls.outline_color = Color.BLACK
		label.label_settings = ls
		btn.add_child(label)
		
		var is_pin_visible := pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
		btn.visible = is_pin_visible
		
		_radar_canvas.add_child(btn)
		btn.pressed.connect(_on_landmark_pin_pressed.bind(landmark))


func _reposition_landmark_pins() -> void:
	var landmarks := MegaStructureService.get_structures()
	for landmark: IMegaStructure in landmarks:
		var btn := _radar_canvas.get_node_or_null("Pin_" + landmark.get_name()) as Button
		if is_instance_valid(btn):
			var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
			btn.position = pin_pos - Vector2(14, 14)
			var is_pin_visible := pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
			btn.visible = is_pin_visible


func _on_landmark_pin_pressed(landmark: IMegaStructure) -> void:
	var p_ctrl := player as PlayerController
	if not is_instance_valid(p_ctrl):
		return
		
	var world_controller_ref := p_ctrl.world_controller as WorldController
	if not is_instance_valid(world_controller_ref):
		return
		
	# 1. Instantiate and display the loading screen immediately
	var hud_node := p_ctrl.hud
	if is_instance_valid(hud_node):
		hud_node.show_loading_screen()
		
	# 2. Temporarily disable the player to prevent physics processing during teleportation
	p_ctrl.is_active = false
	p_ctrl.velocity = Vector3.ZERO
	
	# 3. Yield control to the engine for one frame to force render the loading screen
	await get_tree().process_frame
	
	# 4. Perform the physical teleportation safely while the loading screen is visible
	var target_x := float(landmark.global_center.x) + 0.5
	var target_z := float(landmark.global_center.y) + 0.5
	
	if landmark is StevesCabinMegaStructure: 
		target_z = -294.5 
	elif landmark is NetherPortalMegaStructure: 
		target_x = -290.5
		target_z = -290.5
	elif landmark is GrandCastleMegaStructure: 
		target_x = 200.5
		target_z = 227.5
	elif landmark is HarborCityMegaStructure: 
		target_x = -136.5
		target_z = 3.5
		
	p_ctrl.global_position = Vector3(target_x, 35.0, target_z) 
	world_controller_ref.is_teleport_spawn = true
	
	if is_instance_valid(world_controller_ref.world_state):
		var chunk_pos := world_controller_ref.world_state.global_to_chunk_pos(Vector3i(floori(target_x), 0, floori(target_z)))
		world_controller_ref.set("_target_spawn_chunk_pos", chunk_pos)
		
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_world_map") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play_exit_animation()
