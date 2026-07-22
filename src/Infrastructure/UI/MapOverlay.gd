# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/MapOverlay.gd
# Description: Infrastructure Coordinator strictly managing Tactical World Map
#              projections, click-and-drag panning, and fast-travel teleportation.
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

var _scanline_pos: float = 0.0
var _pulse_timer: float = 0.0
var _map_center: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_center: Vector2 = Vector2.ZERO

var _biome_map_texture: ImageTexture
var _map_panel_size: float = 380.0

const MAP_COORD_RANGE: float = 800.0
const MAP_BOUNDS_LIMIT: float = 400.0
const GRID_SPACING_METERS: float = 100.0
const QUEST_MARKER_SIZE: float = 8.0
const PLAYER_ARROW_LENGTH: float = 22.0

const COLOR_GRID := Color(0.3, 0.85, 1.0, 0.15)
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_PULSE := Color(0.2, 0.85, 0.85, 0.35)
const COLOR_QUEST := Color(1.0, 0.05, 0.55)

const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.08, 0.45, 0.72), 1: Color(0.28, 0.75, 0.18), 
	2: Color(0.82, 0.75, 0.25), 3: Color(0.38, 0.38, 0.38), 
	4: Color(0.98, 0.98, 0.98), 5: Color(0.18, 0.45, 0.15), 
	6: Color(0.85, 0.38, 0.22), 7: Color(0.0, 0.65, 0.65),  
	8: Color(0.22, 0.18, 0.12), 9: Color(0.95, 0.95, 0.95)  
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
	_scanline_pos = fmod(_scanline_pos + delta * 180.0, _map_panel_size)
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
	if is_instance_valid(_title_label): _title_label.text = tr("MAP_TITLE").to_upper()
	if is_instance_valid(_close_btn): _close_btn.text = tr("SETTINGS_BACK").to_upper()


func _generate_biome_texture() -> void:
	var generator_node := _get_world_generator()
	if not is_instance_valid(generator_node): return
		
	var noise := generator_node.get("_terrain_noise") as FastNoiseLite
	if noise == null: return
	
	var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	for x in range(120):
		for y in range(120):
			var wx: float = ((float(x) / 120.0) - 0.5) * MAP_COORD_RANGE
			var wz: float = ((float(y) / 120.0) - 0.5) * MAP_COORD_RANGE
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(int(wx), int(wz), noise) as BiomeService.BiomeProfile
			img.set_pixel(x, y, RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK) as Color)
			
	_biome_map_texture = ImageTexture.create_from_image(img)


func _get_world_generator() -> WorldGenerator:
	var p_ctrl := player as PlayerController
	if is_instance_valid(p_ctrl) and is_instance_valid(p_ctrl.world_controller):
		return (p_ctrl.world_controller as WorldController).generator as WorldGenerator
	return null


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_is_dragging = (event as InputEventMouseButton).pressed
		_drag_start_pos = (event as InputEventMouseButton).position
		_drag_start_center = _map_center
	elif event is InputEventMouseMotion and _is_dragging:
		_process_map_drag((event as InputEventMouseMotion).position)


func _process_map_drag(mouse_pos: Vector2) -> void:
	var drag_delta := mouse_pos - _drag_start_pos
	var px_to_world_ratio := MAP_COORD_RANGE / _map_panel_size
	
	_map_center = _drag_start_center - (drag_delta * px_to_world_ratio)
	_map_center.x = clampf(_map_center.x, -MAP_BOUNDS_LIMIT, MAP_BOUNDS_LIMIT)
	_map_center.y = clampf(_map_center.y, -MAP_BOUNDS_LIMIT, MAP_BOUNDS_LIMIT)
	
	_reposition_landmark_pins()
	_radar_canvas.queue_redraw()


# ==============================================================================
# DECOMPOSED RADAR DRAWING ROUTINES (< 15 lines per function)
# ==============================================================================

func _on_radar_draw() -> void:
	if not is_instance_valid(_radar_canvas) or not is_instance_valid(player):
		return
		
	var default_font: Font = get_theme_font("font")
	var p_pos: Vector3 = player.global_position
	var p_map_pos := _world_to_map_space(Vector2(p_pos.x, p_pos.z))
	
	_draw_radar_biome_background()
	_draw_radar_grid(default_font)
	_draw_radar_active_quest(p_map_pos)
	_draw_radar_player_indicator(p_map_pos)


func _draw_radar_biome_background() -> void:
	if _biome_map_texture == null: return
	var coord_scale := _map_panel_size / MAP_COORD_RANGE
	var origin_map_pos := Vector2(_map_panel_size / 2.0, _map_panel_size / 2.0) - (_map_center * coord_scale)
	var tex_rect := Rect2(
		origin_map_pos.x - (MAP_COORD_RANGE / 2.0 * coord_scale),
		origin_map_pos.y - (MAP_COORD_RANGE / 2.0 * coord_scale),
		MAP_COORD_RANGE * coord_scale, MAP_COORD_RANGE * coord_scale
	)
	_radar_canvas.draw_texture_rect(_biome_map_texture, tex_rect, false)
	_radar_canvas.draw_rect(Rect2(0, 0, _map_panel_size, _map_panel_size), Color(0.04, 0.04, 0.06, 0.4), true)


func _draw_radar_grid(default_font: Font) -> void:
	var start_x := int(floor((_map_center.x - MAP_COORD_RANGE / 2.0) / GRID_SPACING_METERS) * GRID_SPACING_METERS)
	var end_x := int(ceil((_map_center.x + MAP_COORD_RANGE / 2.0) / GRID_SPACING_METERS) * GRID_SPACING_METERS)
	var start_z := int(floor((_map_center.y - MAP_COORD_RANGE / 2.0) / GRID_SPACING_METERS) * GRID_SPACING_METERS)
	var end_z := int(ceil((_map_center.y + MAP_COORD_RANGE / 2.0) / GRID_SPACING_METERS) * GRID_SPACING_METERS)
	
	for gx in range(start_x, end_x + 100, 100):
		var s_pos := _world_to_map_space(Vector2(float(gx), 0.0))
		if s_pos.x >= 0.0 and s_pos.x <= _map_panel_size:
			_radar_canvas.draw_line(Vector2(s_pos.x, 0), Vector2(s_pos.x, _map_panel_size), COLOR_GRID)
			_radar_canvas.draw_string(default_font, Vector2(s_pos.x + 4, _map_panel_size - 6), str(gx), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID * 2.0)
			
	for gz in range(start_z, end_z + 100, 100):
		var s_pos := _world_to_map_space(Vector2(0.0, float(gz)))
		if s_pos.y >= 0.0 and s_pos.y <= _map_panel_size:
			_radar_canvas.draw_line(Vector2(0, s_pos.y), Vector2(_map_panel_size, s_pos.y), COLOR_GRID)
			_radar_canvas.draw_string(default_font, Vector2(6, s_pos.y - 4), str(gz), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID * 2.0)


func _draw_radar_active_quest(p_map_pos: Vector2) -> void:
	var active_q := QuestService.get_active_quest() as Quest
	if active_q == null or active_q.target_position == Vector3.ZERO: return
		
	var draw_target := _world_to_map_space(Vector2(active_q.target_position.x, active_q.target_position.z))
	var pulse_radius: float = 10.0 + absf(sin(_pulse_timer * 1.5)) * 6.0
	_radar_canvas.draw_circle(draw_target, pulse_radius, Color(COLOR_QUEST.r, COLOR_QUEST.g, COLOR_QUEST.b, 0.22))
	
	var diamond_points := PackedVector2Array([
		draw_target + Vector2(0, -QUEST_MARKER_SIZE), draw_target + Vector2(QUEST_MARKER_SIZE, 0),
		draw_target + Vector2(0, QUEST_MARKER_SIZE), draw_target + Vector2(-QUEST_MARKER_SIZE, 0)
	])
	_radar_canvas.draw_colored_polygon(diamond_points, COLOR_QUEST)
	_radar_canvas.draw_polyline(diamond_points, Color.BLACK, 2.0)
	_draw_dashed_line(p_map_pos, draw_target, Color(COLOR_QUEST.r, COLOR_QUEST.g, COLOR_QUEST.b, 0.55), 2.5, 10.0)


func _draw_radar_player_indicator(p_map_pos: Vector2) -> void:
	if p_map_pos.x < 0 or p_map_pos.x > _map_panel_size or p_map_pos.y < 0 or p_map_pos.y > _map_panel_size:
		return
		
	var p_pulse: float = 12.0 + absf(sin(_pulse_timer)) * 6.0
	_radar_canvas.draw_circle(p_map_pos, p_pulse, COLOR_PULSE)
	_radar_canvas.draw_circle(p_map_pos, 4.0, Color.BLACK)
	_radar_canvas.draw_circle(p_map_pos, 3.0, COLOR_PLAYER)
	
	var look_angle := -player.rotation.y - (PI / 2.0)
	var arrow_end := p_map_pos + Vector2(cos(look_angle), sin(look_angle)) * PLAYER_ARROW_LENGTH
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


func _populate_landmark_pins() -> void:
	for landmark: IMegaStructure in MegaStructureService.get_structures():
		_instantiate_single_pin(landmark)


func _instantiate_single_pin(landmark: IMegaStructure) -> void:
	var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
	var btn := Button.new()
	btn.name = "Pin_" + landmark.get_name()
	btn.custom_minimum_size = Vector2(28, 28)
	btn.size = Vector2(28, 28)
	btn.position = pin_pos - Vector2(14, 14)
	
	_apply_pin_styles(btn, landmark)
	btn.pressed.connect(_on_landmark_pin_pressed.bind(landmark))
	
	var is_pin_visible := pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
	btn.visible = is_pin_visible
	_radar_canvas.add_child(btn)


func _apply_pin_styles(btn: Button, landmark: IMegaStructure) -> void:
	btn.tooltip_text = tr("MAP_TELEPORT_TOOLTIP") % [tr(landmark.get_name()).to_upper(), landmark.global_center.x, landmark.global_center.y]
	
	var style_normal := StyleBoxFlat.new()
	style_normal.set_corner_radius_all(14)
	style_normal.bg_color = Color(1.0, 0.85, 0.2, 0.0)
	style_normal.border_color = Color(1.0, 0.85, 0.2, 0.5)
	style_normal.border_width_left = 2; style_normal.border_width_top = 2
	style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
	
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.9, 0.15, 0.15, 0.4)
	style_hover.border_color = Color(0.95, 0.15, 0.15, 1.0)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	_attach_pin_label(btn, landmark)


func _attach_pin_label(btn: Button, landmark: IMegaStructure) -> void:
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


func _reposition_landmark_pins() -> void:
	for landmark: IMegaStructure in MegaStructureService.get_structures():
		var btn := _radar_canvas.get_node_or_null("Pin_" + landmark.get_name()) as Button
		if is_instance_valid(btn):
			var pin_pos := _world_to_map_space(Vector2(landmark.global_center.x, landmark.global_center.y))
			btn.position = pin_pos - Vector2(14, 14)
			var is_pin_visible := pin_pos.x >= 0 and pin_pos.x <= _map_panel_size and pin_pos.y >= 0 and pin_pos.y <= _map_panel_size
			btn.visible = is_pin_visible


func _on_landmark_pin_pressed(landmark: IMegaStructure) -> void:
	var p_ctrl := player as PlayerController
	if not is_instance_valid(p_ctrl) or not is_instance_valid(p_ctrl.world_controller): return
		
	if is_instance_valid(p_ctrl.hud): p_ctrl.hud.show_loading_screen()
	p_ctrl.is_active = false
	p_ctrl.velocity = Vector3.ZERO
	
	await get_tree().process_frame
	_execute_fast_travel_teleport(p_ctrl, landmark)


func _execute_fast_travel_teleport(p_ctrl: PlayerController, landmark: IMegaStructure) -> void:
	var target_x := float(landmark.global_center.x) + 0.5
	var target_z := float(landmark.global_center.y) + 0.5
	
	if landmark is StevesCabinMegaStructure: target_z = -294.5 
	elif landmark is NetherPortalMegaStructure: target_x = -290.5; target_z = -290.5
	elif landmark is GrandCastleMegaStructure: target_x = 200.5; target_z = 227.5
	elif landmark is HarborCityMegaStructure: target_x = -136.5; target_z = 3.5
		
	p_ctrl.global_position = Vector3(target_x, 35.0, target_z) 
	var world_ctrl := p_ctrl.world_controller as WorldController
	world_ctrl.is_teleport_spawn = true
	
	if is_instance_valid(world_ctrl.world_state):
		var chunk_pos := world_ctrl.world_state.global_to_chunk_pos(Vector3i(floori(target_x), 0, floori(target_z)))
		world_ctrl.set("_target_spawn_chunk_pos", chunk_pos)
		
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_world_map") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play_exit_animation()
