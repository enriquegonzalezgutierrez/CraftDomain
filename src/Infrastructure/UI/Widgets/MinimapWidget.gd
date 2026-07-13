# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/MinimapWidget.gd
# Description: HUD Minimap Widget responsible for calculating and drawing 
#              procedural 2D biome backgrounds and real-time tactical entity 
#              gliphs on the chronological circular radar (SRP).
#              Corrected: Solved Vector2/Vector3 typemismatch on line 234.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MinimapWidget
extends Control

# Symmetrical Pin Types matching original structure
enum PinType {
	NONE = -1,
	ANIMAL = 0,
	NPC = 1,
	DEFENDER = 2,
	HOSTILE = 3,
	CHEST = 4,
	CAMPFIRE = 5,
	LIGHT = 6
}

# OCP Mapping of entity names to their clean single-char radar symbols (Section 5.3)
const SYMBOL_CHAR_MAPPING: Dictionary = {
	"ZOMBIE": "Z", "SHARK": "S", "GARGOYLE": "G", "GOBLIN": "K",
	"GOLEM": "I", "GUARD": "K", "MERCHANT": "$", "FARMER": "F",
	"MINER": "M", "DRUID": "D", "CYBER": "A", "PIG": "p",
	"CHICKEN": "c", "SHEEP": "s", "COW": "w", "FOX": "f",
	"CAT": "m", "GROWLITHE": "d", "MONKEY": "k", "OCTOPUS": "o",
	"TURTLE": "t", "RACCOON": "r", "BIRD": "b", "PARROT": "y",
	"CRAB": "a"
}

var player: CharacterBody3D
var world_controller: Node3D

@onready var _radar_canvas: Control = $ClippingMask/RadarCanvas
@onready var _border_canvas: Control = $BorderCanvas

# Throttling timer parameters
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.04 

const SIZE_DIM: float = 160.0
const CENTER := Vector2(80.0, 80.0)
const MAX_RADIUS: float = 78.0
const MAX_RADIUS_SQ: float = 5776.0

const COLOR_GRID := Color(1.0, 1.0, 1.0, 0.08)
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_PULSE := Color(0.2, 0.85, 0.85, 0.35)
const COLOR_QUEST := Color(1.0, 0.05, 0.55)

const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.08, 0.45, 0.72), 1: Color(0.28, 0.75, 0.18), 
	2: Color(0.92, 0.85, 0.35), 3: Color(0.48, 0.48, 0.48), 
	4: Color(0.98, 0.98, 0.98), 5: Color(0.18, 0.45, 0.15), 
	6: Color(0.85, 0.38, 0.22), 7: Color(0.0, 0.65, 0.65),  
	8: Color(0.28, 0.22, 0.15), 9: Color(1.0, 1.0, 1.0)     
}

var _cached_biome_colors: Dictionary = {} 
var _last_chunk_center := Vector2(-99999, -99999)


func _ready() -> void:
	_radar_canvas.draw.connect(_on_radar_draw)
	_border_canvas.draw.connect(_on_border_draw)


func update_widget() -> void:
	var delta := get_process_delta_time()
	_update_timer += delta
	
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		if is_instance_valid(_radar_canvas):
			_radar_canvas.queue_redraw()
		if is_instance_valid(_border_canvas):
			_border_canvas.queue_redraw()


func _update_biome_cache(chunk_center_x: float, chunk_center_z: float) -> void:
	var generator := world_controller.get("generator") as WorldGenerator if is_instance_valid(world_controller) else null
	if not is_instance_valid(generator): return
	var terrain_noise := generator.get("_terrain_noise") as FastNoiseLite
	if terrain_noise == null: return
	
	_cached_biome_colors.clear()
	var grid_radius := 6
	
	for cx in range(-grid_radius, grid_radius + 1):
		for cz in range(-grid_radius, grid_radius + 1):
			var sample_x := int(chunk_center_x) + (cx * 16)
			var sample_z := int(chunk_center_z) + (cz * 16)
			
			var profile := BiomeService.evaluate_coordinate(sample_x, sample_z, terrain_noise) as BiomeService.BiomeProfile
			_cached_biome_colors[Vector2i(cx, cz)] = RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK)


func _on_radar_draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller): 
		return
		
	var player_pos := player.global_position
	var grid_radius := 6
	var step_size := 16.0
	
	var chunk_center_x := floorf(player_pos.x / 16.0) * 16.0 + 8.0
	var chunk_center_z := floorf(player_pos.z / 16.0) * 16.0 + 8.0
	var current_center := Vector2(chunk_center_x, chunk_center_z)
	
	if current_center != _last_chunk_center:
		_last_chunk_center = current_center
		_update_biome_cache(chunk_center_x, chunk_center_z)
		
	var player_offset := Vector2(player_pos.x - chunk_center_x, player_pos.z - chunk_center_z)
	
	for cx in range(-grid_radius, grid_radius + 1):
		for cz in range(-grid_radius, grid_radius + 1):
			var coord := Vector2i(cx, cz)
			var biome_color: Color = _cached_biome_colors.get(coord, Color.BLACK)
			var draw_pos := CENTER + (Vector2(float(cx), float(cz)) * step_size) - player_offset - Vector2(8.0, 8.0)
			_radar_canvas.draw_rect(Rect2(draw_pos, Vector2(16, 16)), biome_color, true)
			_radar_canvas.draw_rect(Rect2(draw_pos, Vector2(16, 16)), Color(0.0, 0.0, 0.0, 0.12), false, 1.0)

	_radar_canvas.draw_line(CENTER - Vector2(MAX_RADIUS, 0), CENTER + Vector2(MAX_RADIUS, 0), COLOR_GRID, 1.0)
	_radar_canvas.draw_line(CENTER - Vector2(0, MAX_RADIUS), CENTER + Vector2(0, MAX_RADIUS), COLOR_GRID, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.4, COLOR_GRID, false, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.75, COLOR_GRID, false, 1.0)

	for child: Node in world_controller.get_children():
		if not is_instance_valid(child) or not (child is Node3D):
			continue
			
		var child_pos: Vector3 = child.get("global_position") as Vector3
		var pin_type: PinType = PinType.NONE
		var is_valid_entity := false
		
		if child.has_meta("minimap_pin_type"):
			pin_type = child.get_meta("minimap_pin_type") as PinType
			is_valid_entity = true
		elif child.has_method("get_minimap_pin_type"):
			pin_type = child.call("get_minimap_pin_type") as PinType
			is_valid_entity = true
		else:
			if child.is_in_group("hostiles"):
				pin_type = PinType.HOSTILE
				is_valid_entity = true
			elif child.is_in_group("passives"):
				if child.has_method("_get_humanoid_role") and child.call("_get_humanoid_role") == -1:
					pin_type = PinType.ANIMAL
				else:
					pin_type = PinType.NPC
				is_valid_entity = true
			
		if is_valid_entity and pin_type != PinType.NONE:
			var diff := Vector2(child_pos.x - player_pos.x, child_pos.z - player_pos.z)
			if diff.length_squared() < MAX_RADIUS_SQ:
				_draw_tactical_symbol(CENTER + diff, pin_type, child_pos.y - player_pos.y, child.name)


func _draw_tactical_symbol(draw_pos: Vector2, type: PinType, delta_y: float, node_name: String) -> void:
	var is_different_level := absf(delta_y) > 6.0
	var alpha := 0.45 if is_different_level else 1.0
	var base_color := Color.WHITE
	
	match type:
		PinType.CAMPFIRE:
			base_color = Color(1.0, 0.45, 0.0, alpha)
			var triangle := PackedVector2Array([draw_pos + Vector2(0, -4.5), draw_pos + Vector2(3.5, 2.5), draw_pos + Vector2(-3.5, 2.5)])
			_radar_canvas.draw_colored_polygon(triangle, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color(0,0,0, alpha), 1.0)
		PinType.ANIMAL:
			base_color = Color(0.35, 0.85, 0.25, alpha)
			var triangle := PackedVector2Array([draw_pos + Vector2(0, 3.5), draw_pos + Vector2(2.5, -1.5), draw_pos + Vector2(-2.5, -1.5)])
			_radar_canvas.draw_colored_polygon(triangle, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color(0,0,0, alpha), 1.0)
		PinType.DEFENDER:
			base_color = Color(0.2, 0.55, 1.0, alpha)
			var diamond := PackedVector2Array([draw_pos + Vector2(0, -3.2), draw_pos + Vector2(3.2, 0), draw_pos + Vector2(0, 3.2), draw_pos + Vector2(-3.2, 0)])
			_radar_canvas.draw_colored_polygon(diamond, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0,0,0, alpha), 1.0)
		PinType.NPC:
			base_color = Color(0.0, 0.85, 0.85, alpha)
			var hex := PackedVector2Array([
				draw_pos + Vector2(0, -2.6), draw_pos + Vector2(2.25, -1.3), draw_pos + Vector2(2.25, 1.3),
				draw_pos + Vector2(0, 2.6), draw_pos + Vector2(-2.25, 1.3), draw_pos + Vector2(-2.25, -1.3)
			])
			_radar_canvas.draw_colored_polygon(hex, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([hex[0], hex[1], hex[2], hex[3], hex[4], hex[5], hex[0]]), Color(0,0,0, alpha), 1.0)
		PinType.HOSTILE:
			base_color = Color(0.95, 0.15, 0.15, alpha)
			_radar_canvas.draw_line(draw_pos + Vector2(-2.5, -2.5), draw_pos + Vector2(2.5, 2.5), Color(0,0,0, alpha), 3.5)
			_radar_canvas.draw_line(draw_pos + Vector2(2.5, -2.5), draw_pos + Vector2(-2.5, 2.5), Color(0,0,0, alpha), 3.5)
			_radar_canvas.draw_line(draw_pos + Vector2(-2.5, -2.5), draw_pos + Vector2(2.5, 2.5), base_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(2.5, -2.5), draw_pos + Vector2(-2.5, 2.5), base_color, 1.5)
		PinType.CHEST:
			base_color = Color(1.0, 0.82, 0.2, alpha)
			var rect := Rect2(draw_pos - Vector2(2, 2), Vector2(4, 4))
			_radar_canvas.draw_rect(rect, base_color, true)
			_radar_canvas.draw_rect(rect, Color(0,0,0, alpha), false, 1.0)
			
	# PROJECT HOLOGRAPHIC CHARACTER OVER DETECTOR (OCP / Section 3.2)
	_draw_holographic_glyph_on_pin(draw_pos, node_name, alpha)
			
	if is_different_level:
		var arrow_color := Color(base_color.r, base_color.g, base_color.b, 0.72)
		if delta_y < -6.0:
			_radar_canvas.draw_line(draw_pos + Vector2(-3, 6), draw_pos + Vector2(0, 9), arrow_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(3, 6), draw_pos + Vector2(0, 9), arrow_color, 1.5)
		elif delta_y > 6.0:
			_radar_canvas.draw_line(draw_pos + Vector2(-3, -6), draw_pos + Vector2(0, -9), arrow_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(3, -6), draw_pos + Vector2(0, -9), arrow_color, 1.5)


## Helper: Projects high-contrast centered abbreviations on pins to ensure absolute legibility
func _draw_holographic_glyph_on_pin(draw_pos: Vector2, node_name: String, alpha: float) -> void:
	var glyph := _get_glyph_for_entity(node_name)
	if glyph == "":
		return
		
	var default_font: Font = get_theme_font("font")
	# Calibrated font size 8 for perfect visual scaling inside radar pins
	var font_size := 8
	var text_color := Color(1.0, 1.0, 1.0, alpha)
	var shadow_color := Color(0.0, 0.0, 0.0, alpha * 0.75)
	
	var half_width := default_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x / 2.0
	var offset_y := 3.0 # Centering Y baseline
	
	# COORDINATE FIXED: Symmetrical 2D Vector addition
	var final_draw_pos := draw_pos + Vector2(-half_width, offset_y)
	
	# Draw drop shadow for extreme readibility over map terrain (Section 1.2)
	_radar_canvas.draw_string(default_font, final_draw_pos + Vector2(1, 1), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
	_radar_canvas.draw_string(default_font, final_draw_pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


## Pure helper resolving abbreviations deterministically from static mappings
func _get_glyph_for_entity(node_name: String) -> String:
	var upper_name := node_name.to_upper()
	for key: String in SYMBOL_CHAR_MAPPING.keys():
		if upper_name.contains(key):
			return SYMBOL_CHAR_MAPPING[key] as String
	return ""


func _on_border_draw() -> void:
	if not is_instance_valid(player): return
	var player_pos := player.global_position
	
	for i in range(12):
		var r: float = MAX_RADIUS - float(i)
		var alpha: float = (float(12 - i) / 12.0) * 0.35
		_border_canvas.draw_circle(CENTER, r, Color(0.04, 0.04, 0.06, alpha), false, 1.5)

	_border_canvas.draw_circle(CENTER, 80.0, Color(0.1, 0.1, 0.12, 0.5), false, 6.0)
	_border_canvas.draw_circle(CENTER, 80.0, Color(0.3, 0.3, 0.35, 0.9), false, 2.0)

	var default_font: Font = get_theme_font("font")
	var compass_color := Color(1.0, 0.85, 0.2)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y - 79.0), tr("DIR_N").left(1).to_upper(), 11, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y + 79.0), tr("DIR_S").left(1).to_upper(), 11, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x + 79.0, CENTER.y), tr("DIR_E").left(1).to_upper(), 11, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x - 79.0, CENTER.y), tr("DIR_W").left(1).to_upper(), 11, compass_color)

	var active_q := QuestService.get_active_quest() as Quest
	if active_q != null and active_q.target_position != Vector3.ZERO:
		var q_pos := active_q.target_position
		var diff_vec := Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos := diff_vec
		if radar_pos.length_squared() > 5476.0:
			radar_pos = radar_pos.normalized() * 74.0
			
		var draw_target := CENTER + radar_pos
		var pulse_radius: float = 8.0 + absf(sin(Time.get_ticks_msec() / 250.0)) * 6.0
		_border_canvas.draw_circle(draw_target, pulse_radius, Color(1.0, 0.05, 0.55, 0.22))
		
		var diamond_points := PackedVector2Array([draw_target + Vector2(0, -6), draw_target + Vector2(6, 0), draw_target + Vector2(0, 6), draw_target + Vector2(-6, 0)])
		_border_canvas.draw_colored_polygon(diamond_points, Color(1.0, 0.05, 0.55))
		_border_canvas.draw_polyline(PackedVector2Array([diamond_points[0], diamond_points[1], diamond_points[2], diamond_points[3], diamond_points[0]]), Color.BLACK, 1.5)
		_draw_dashed_gps_line(CENTER, draw_target, Color(1.0, 0.05, 0.55, 0.72), 2.0, 6.0)

	_border_canvas.draw_circle(CENTER, 4.0, Color(0.2, 0.2, 0.2, 0.6))
	_border_canvas.draw_circle(CENTER, 3.0, Color.WHITE)
	_border_canvas.draw_circle(CENTER, 3.0, Color.BLACK, false, 1.0)
	
	var look_angle := -player.rotation.y - (PI / 2.0)
	var arrow_end := CENTER + Vector2(cos(look_angle), sin(look_angle)) * 12.0
	_border_canvas.draw_line(CENTER, arrow_end, Color.BLACK, 3.5)
	_border_canvas.draw_line(CENTER, arrow_end, Color.WHITE, 1.5)


func _draw_dashed_gps_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var current_dist := 0.0
	while current_dist < length:
		var start := from + dir * current_dist
		var end := from + dir * minf(current_dist + dash_length, length)
		_border_canvas.draw_line(start, end, color, width)
		current_dist += dash_length * 2.0


func _draw_holographic_compass_plate(f: Font, plate_pos: Vector2, text_char: String, f_size: int, text_color: Color) -> void:
	var radius := 10.0
	_border_canvas.draw_circle(plate_pos, radius, Color(0.06, 0.06, 0.08, 0.95))
	_border_canvas.draw_circle(plate_pos, radius, Color(0.2, 0.85, 0.28, 0.65), false, 1.5)
	var start_x := plate_pos.x - radius
	var diameter := radius * 2.0
	var font_height := f.get_height(f_size)
	var font_ascent := f.get_ascent(f_size)
	var baseline_y := plate_pos.y + font_ascent - (font_height / 2.0)
	_border_canvas.draw_string(f, Vector2(start_x, baseline_y), text_char, HORIZONTAL_ALIGNMENT_CENTER, diameter, f_size, text_color)
