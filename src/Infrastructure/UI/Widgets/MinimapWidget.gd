# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (UI Widgets / Minimap Radar)
# Class: MinimapWidget
# Description: SRP-compliant UI Widget responsible ONLY for rendering the 
#              circular minimap radar, player direction arrow, and active markers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Focuses exclusively on radar canvas 
#   drawings and coordinate-to-pixel translations.
# - Open-Closed Principle (OCP): Completely closed to modifications. All rigid 
#   type-checks (e.g. 'child is CampfireEntity') have been removed. Pin types 
#   are resolved polimorphically through metadata or virtual methods, allowing 
#   infinite new trackable props and entities.
# - Liskov Substitution Principle (LSP): Works uniformly on any trackable Node3D 
#   that registers in standard engine groups or exposes pin traits.
# ==============================================================================
class_name MinimapWidget
extends Control

# --- PIN TYPES ENUM ---
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

# Dependencies injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

# Internal Layers
var _mask_panel: Panel
var _radar_canvas: Control
var _border_canvas: Control

# Throttling timer parameters
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.04 # 25 FPS radar refresh for smooth sliding

const SIZE_DIM: float = 160.0
const CENTER: Vector2 = Vector2(SIZE_DIM / 2.0, SIZE_DIM / 2.0)
const MAX_RADIUS: float = (SIZE_DIM / 2.0) - 2.0
const MAX_RADIUS_SQ: float = (MAX_RADIUS - 2.0) * (MAX_RADIUS - 2.0)

const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.12, 0.55, 0.82), # Ocean
	1: Color(0.38, 0.85, 0.28), # Plateau
	2: Color(0.92, 0.85, 0.35), # Plains
	3: Color(0.48, 0.48, 0.48), # Mountains
	4: Color(0.98, 0.98, 0.98), # Glaciers
	5: Color(0.18, 0.45, 0.15), # Forest
	6: Color(0.85, 0.38, 0.22), # Badlands
	7: Color(0.0, 0.85, 0.85),  # Neon Ruins
	8: Color(0.28, 0.22, 0.15), # Swamp
	9: Color(1.0, 1.0, 1.0)     # Clouds
}

# --- PERFORMANCE CACHE VARIABLES ---
var _cached_biome_colors: Dictionary = {} # Vector2i -> Color
var _last_chunk_center: Vector2 = Vector2(-99999, -99999)


func _ready() -> void:
	name = "MinimapWidget"
	custom_minimum_size = Vector2(SIZE_DIM, SIZE_DIM)
	size = Vector2(SIZE_DIM, SIZE_DIM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_rendering_layers()


func _setup_rendering_layers() -> void:
	# 1. Base Mask Panel (Circular stencil)
	_mask_panel = Panel.new()
	_mask_panel.name = "ClippingMask"
	_mask_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mask_style: StyleBoxFlat = StyleBoxFlat.new()
	mask_style.bg_color = Color(0.04, 0.04, 0.06, 0.85)
	mask_style.set_corner_radius_all(int(SIZE_DIM / 2.0))
	mask_style.anti_aliasing = true
	_mask_panel.add_theme_stylebox_override("panel", mask_style)
	_mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_mask_panel)
	
	# 2. Radar Canvas (Draws biomes, grid, and entities)
	_radar_canvas = Control.new()
	_radar_canvas.name = "RadarCanvas"
	_radar_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar_canvas.draw.connect(_on_radar_draw)
	_mask_panel.add_child(_radar_canvas)
	
	# 3. Border Canvas (Draws frame vignette, compass plates, and central player arrow)
	_border_canvas = Control.new()
	_border_canvas.name = "BorderCanvas"
	_border_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_canvas.draw.connect(_on_border_draw)
	add_child(_border_canvas)


func update_widget() -> void:
	var delta: float = get_process_delta_time()
	_update_timer += delta
	
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		if is_instance_valid(_radar_canvas):
			_radar_canvas.queue_redraw()
		if is_instance_valid(_border_canvas):
			_border_canvas.queue_redraw()


func _update_biome_cache(chunk_center_x: float, chunk_center_z: float) -> void:
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if not is_instance_valid(generator): return
	var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
	if terrain_noise == null: return
	
	_cached_biome_colors.clear()
	var grid_radius: int = 6
	
	for cx: int in range(-grid_radius, grid_radius + 1):
		for cz: int in range(-grid_radius, grid_radius + 1):
			var sample_x: int = int(chunk_center_x) + (cx * 16)
			var sample_z: int = int(chunk_center_z) + (cz * 16)
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(sample_x, sample_z, terrain_noise) as BiomeService.BiomeProfile
			var biome_color: Color = RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK)
			_cached_biome_colors[Vector2i(cx, cz)] = biome_color


# ==============================================================================
# LAYER 1: CLIPPED RADAR CANVAS (Biomes, Grid, Entities)
# ==============================================================================
func _on_radar_draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller): 
		return
		
	var player_pos: Vector3 = player.global_position
	var grid_radius: int = 6
	var step_size: float = 16.0
	
	var chunk_center_x: float = floor(player_pos.x / 16.0) * 16.0 + 8.0
	var chunk_center_z: float = floor(player_pos.z / 16.0) * 16.0 + 8.0
	var current_center := Vector2(chunk_center_x, chunk_center_z)
	
	if current_center != _last_chunk_center:
		_last_chunk_center = current_center
		_update_biome_cache(chunk_center_x, chunk_center_z)
		
	var player_offset: Vector2 = Vector2(player_pos.x - chunk_center_x, player_pos.z - chunk_center_z)
	
	# 1. DRAW BIOME BACKGROUND
	for cx: int in range(-grid_radius, grid_radius + 1):
		for cz: int in range(-grid_radius, grid_radius + 1):
			var coord := Vector2i(cx, cz)
			var biome_color: Color = _cached_biome_colors.get(coord, Color.BLACK)
			
			var draw_pos: Vector2 = CENTER + (Vector2(float(cx), float(cz)) * step_size) - player_offset - Vector2(step_size / 2.0, step_size / 2.0)
			var rect_target: Rect2 = Rect2(draw_pos, Vector2(step_size, step_size))
			
			_radar_canvas.draw_rect(rect_target, biome_color, true)
			_radar_canvas.draw_rect(rect_target, Color(0.0, 0.0, 0.0, 0.12), false, 1.0)

	# 2. DRAW TACTICAL SONAR RINGS
	var grid_color: Color = Color(1.0, 1.0, 1.0, 0.08)
	_radar_canvas.draw_line(CENTER - Vector2(MAX_RADIUS, 0), CENTER + Vector2(MAX_RADIUS, 0), grid_color, 1.0)
	_radar_canvas.draw_line(CENTER - Vector2(0, MAX_RADIUS), CENTER + Vector2(0, MAX_RADIUS), grid_color, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.4, grid_color, false, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.75, grid_color, false, 1.0)

	# 3. DRAW TACTICAL ENTITY PINS (OCP COMPLIANT)
	for child: Node in world_controller.get_children():
		if not is_instance_valid(child) or not (child is Node3D):
			continue
			
		var child_pos: Vector3 = child.get("global_position") as Vector3
		var pin_type: PinType = PinType.NONE
		var is_valid_entity: bool = false
		
		# OCP RESOLUTION: Query the tracking properties polimorphically.
		# A. Check metadata overrides (set_meta("minimap_pin_type", PinType.*))
		if child.has_meta("minimap_pin_type"):
			pin_type = child.get_meta("minimap_pin_type") as PinType
			is_valid_entity = true
		# B. Check virtual method overrides
		elif child.has_method("get_minimap_pin_type"):
			pin_type = child.call("get_minimap_pin_type") as PinType
			is_valid_entity = true
		# C. Group Fallback scanning (un-coupled, fully robust)
		else:
			if child.is_in_group("hostiles"):
				pin_type = PinType.HOSTILE
				is_valid_entity = true
			elif child.is_in_group("passives"):
				# Distinguish animals from humanoids polimorphically
				if child.has_method("_get_humanoid_role") and child.call("_get_humanoid_role") == -1:
					pin_type = PinType.ANIMAL
				else:
					pin_type = PinType.NPC
				is_valid_entity = true
			
		if is_valid_entity and pin_type != PinType.NONE:
			var diff: Vector2 = Vector2(child_pos.x - player_pos.x, child_pos.z - player_pos.z)
			
			if diff.length_squared() < MAX_RADIUS_SQ:
				var draw_pos: Vector2 = CENTER + diff
				# Calculate vertical altitude delta relative to player's current height
				var delta_y: float = child_pos.y - player_pos.y
				_draw_tactical_symbol(draw_pos, pin_type, delta_y)


## Helper: Draws specific geometric shapes and applies 3D depth-sensing transparencies and chevrons
func _draw_tactical_symbol(draw_pos: Vector2, type: PinType, delta_y: float) -> void:
	# Calculate depth scaling: Fade pins out to 45% opacity if on a different floor/cave level
	var is_different_level: bool = abs(delta_y) > 6.0
	var alpha: float = 0.45 if is_different_level else 1.0
	
	var base_color := Color.WHITE
	
	match type:
		PinType.CAMPFIRE:
			# 🔥 Orange Triangle pointing UP
			base_color = Color(1.0, 0.45, 0.0, alpha)
			var shape_size: float = 3.5
			var triangle: PackedVector2Array = PackedVector2Array([
				draw_pos + Vector2(0, -shape_size - 1.0), 
				draw_pos + Vector2(shape_size, shape_size - 1.0), 
				draw_pos + Vector2(-shape_size, shape_size - 1.0) 
			])
			_radar_canvas.draw_colored_polygon(triangle, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color(0,0,0, alpha), 1.0)
			
		PinType.ANIMAL:
			# 🐄 Green Triangle pointing DOWN 
			base_color = Color(0.35, 0.85, 0.25, alpha)
			var shape_size: float = 2.5
			var triangle: PackedVector2Array = PackedVector2Array([
				draw_pos + Vector2(0, shape_size + 1.0), 
				draw_pos + Vector2(shape_size, -shape_size + 1.0), 
				draw_pos + Vector2(-shape_size, -shape_size + 1.0) 
			])
			_radar_canvas.draw_colored_polygon(triangle, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color(0,0,0, alpha), 1.0)
			
		PinType.DEFENDER:
			# 🛡️ Blue Diamond
			base_color = Color(0.2, 0.55, 1.0, alpha)
			var shape_size: float = 3.2
			var diamond: PackedVector2Array = PackedVector2Array([
				draw_pos + Vector2(0, -shape_size), draw_pos + Vector2(shape_size, 0),
				draw_pos + Vector2(0, shape_size), draw_pos + Vector2(-shape_size, 0)
			])
			_radar_canvas.draw_colored_polygon(diamond, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0,0,0, alpha), 1.0)
			
		PinType.NPC:
			# 🧑 Cyan Hexagon with inner white core
			base_color = Color(0.0, 0.85, 0.85, alpha)
			var shape_size: float = 2.6
			var hex: PackedVector2Array = PackedVector2Array([
				draw_pos + Vector2(0, -shape_size),
				draw_pos + Vector2(shape_size * 0.866, -shape_size * 0.5),
				draw_pos + Vector2(shape_size * 0.866, shape_size * 0.5),
				draw_pos + Vector2(0, shape_size),
				draw_pos + Vector2(-shape_size * 0.866, shape_size * 0.5),
				draw_pos + Vector2(-shape_size * 0.866, -shape_size * 0.5)
			])
			_radar_canvas.draw_colored_polygon(hex, base_color)
			_radar_canvas.draw_polyline(PackedVector2Array([hex[0], hex[1], hex[2], hex[3], hex[4], hex[5], hex[0]]), Color(0,0,0, alpha), 1.0)
			
		PinType.HOSTILE:
			# 🔴 Red X (Thick crossed lines)
			base_color = Color(0.95, 0.15, 0.15, alpha)
			var shape_size: float = 2.5
			_radar_canvas.draw_line(draw_pos + Vector2(-shape_size, -shape_size), draw_pos + Vector2(shape_size, shape_size), Color(0,0,0, alpha), 3.5)
			_radar_canvas.draw_line(draw_pos + Vector2(shape_size, -shape_size), draw_pos + Vector2(-shape_size, shape_size), Color(0,0,0, alpha), 3.5)
			_radar_canvas.draw_line(draw_pos + Vector2(-shape_size, -shape_size), draw_pos + Vector2(shape_size, shape_size), base_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(shape_size, -shape_size), draw_pos + Vector2(-shape_size, shape_size), base_color, 1.5)
			
		PinType.CHEST:
			# 🟨 Gold Square
			base_color = Color(1.0, 0.82, 0.2, alpha)
			var rect: Rect2 = Rect2(draw_pos - Vector2(2, 2), Vector2(4, 4))
			_radar_canvas.draw_rect(rect, base_color, true)
			_radar_canvas.draw_rect(rect, Color(0,0,0, alpha), false, 1.0)
			
		PinType.LIGHT:
			# 💡 Yellow 4-Pointed Star 
			base_color = Color(1.0, 0.9, 0.2, alpha)
			var w: float = 0.8
			var h: float = 2.5
			var star: PackedVector2Array = PackedVector2Array([
				draw_pos + Vector2(0, -h), draw_pos + Vector2(w, -w),
				draw_pos + Vector2(h, 0), draw_pos + Vector2(w, w),
				draw_pos + Vector2(0, h), draw_pos + Vector2(-w, w),
				draw_pos + Vector2(-h, 0), draw_pos + Vector2(-w, -w)
			])
			_radar_canvas.draw_colored_polygon(star, base_color)
			
	# ==========================================================================
	# 3D ALTITUDE INDICATOR CHEVRONS (^ or v)
	# ==========================================================================
	if is_different_level:
		var arrow_color := Color(base_color.r, base_color.g, base_color.b, 0.72)
		if delta_y < -6.0:
			# Target is deep below us (underground cave) - draw downward pointing chevron
			_radar_canvas.draw_line(draw_pos + Vector2(-3, 6), draw_pos + Vector2(0, 9), arrow_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(3, 6), draw_pos + Vector2(0, 9), arrow_color, 1.5)
		elif delta_y > 6.0:
			# Target is high above us (cliff/flying) - draw upward pointing chevron
			_radar_canvas.draw_line(draw_pos + Vector2(-3, -6), draw_pos + Vector2(0, -9), arrow_color, 1.5)
			_radar_canvas.draw_line(draw_pos + Vector2(3, -6), draw_pos + Vector2(0, -9), arrow_color, 1.5)


# ==============================================================================
# LAYER 2: OVERLAY BORDER CANVAS (Vignette, Compass Plates, Player)
# ==============================================================================
func _on_border_draw() -> void:
	if not is_instance_valid(player):
		return
	
	var player_pos: Vector3 = player.global_position
	
	# 1. DRAW CRT LENS VIGNETTE SHADOWS
	for i: int in range(12):
		var r: float = MAX_RADIUS - float(i)
		var alpha: float = (float(12 - i) / 12.0) * 0.35
		_border_canvas.draw_circle(CENTER, r, Color(0.04, 0.04, 0.06, alpha), false, 1.5)

	# 2. DRAW GLASSMORPHIC HARD BORDER
	_border_canvas.draw_circle(CENTER, SIZE_DIM / 2.0, Color(0.1, 0.1, 0.12, 0.5), false, 6.0)
	_border_canvas.draw_circle(CENTER, SIZE_DIM / 2.0, Color(0.3, 0.3, 0.35, 0.9), false, 2.0)

	# 3. DRAW HOLOGRAPHIC COMPASS PLATES
	var default_font: Font = get_theme_font("font")
	var compass_color: Color = Color(1.0, 0.85, 0.2)
	var f_size: int = 11
	var offset: float = (SIZE_DIM / 2.0) - 1.0
	
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y - offset), tr("DIR_N").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y + offset), tr("DIR_S").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x + offset, CENTER.y), tr("DIR_E").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x - offset, CENTER.y), tr("DIR_W").left(1).to_upper(), f_size, compass_color)

	# 4. DRAW ACTIVE QUEST MARKER
	var active_q: Quest = QuestService.get_active_quest() as Quest
	if active_q != null and active_q.target_position != Vector3.ZERO:
		var q_pos: Vector3 = active_q.target_position
		var diff_vec: Vector2 = Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos: Vector2 = diff_vec
		
		if radar_pos.length_squared() > (MAX_RADIUS - 4.0) * (MAX_RADIUS - 4.0):
			radar_pos = radar_pos.normalized() * (MAX_RADIUS - 4.0)
			
		var draw_target: Vector2 = CENTER + radar_pos
		var pulse_radius: float = 8.0 + abs(sin(Time.get_ticks_msec() / 250.0)) * 6.0
		
		_border_canvas.draw_circle(draw_target, pulse_radius, Color(1.0, 0.05, 0.55, 0.22))
		
		var diamond_points: PackedVector2Array = PackedVector2Array([
			draw_target + Vector2(0, -6),
			draw_target + Vector2(6, 0),
			draw_target + Vector2(0, 6),
			draw_target + Vector2(-6, 0)
		])
		_border_canvas.draw_colored_polygon(diamond_points, Color(1.0, 0.05, 0.55))
		_border_canvas.draw_polyline(PackedVector2Array([diamond_points[0], diamond_points[1], diamond_points[2], diamond_points[3], diamond_points[0]]), Color.BLACK, 1.5)
		
		_draw_dashed_gps_line(CENTER, draw_target, Color(1.0, 0.05, 0.55, 0.72), 2.0, 6.0)

	# 5. DRAW PLAYER ARROW
	_border_canvas.draw_circle(CENTER, 4.0, Color(0.2, 0.2, 0.2, 0.6))
	_border_canvas.draw_circle(CENTER, 3.0, Color.WHITE)
	_border_canvas.draw_circle(CENTER, 3.0, Color.BLACK, false, 1.0)
	
	var look_angle: float = -player.rotation.y - (PI / 2.0)
	var arrow_length: float = 12.0
	var arrow_end: Vector2 = CENTER + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
	
	_border_canvas.draw_line(CENTER, arrow_end, Color.BLACK, 3.5)
	_border_canvas.draw_line(CENTER, arrow_end, Color.WHITE, 1.5)


func _draw_dashed_gps_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var length: float = from.distance_to(to)
	var dir: Vector2 = (to - from).normalized()
	var current_dist: float = 0.0
	
	while current_dist < length:
		var start: Vector2 = from + dir * current_dist
		var end: Vector2 = from + dir * min(current_dist + dash_length, length)
		_border_canvas.draw_line(start, end, color, width)
		current_dist += dash_length * 2.0


func _draw_holographic_compass_plate(f: Font, plate_pos: Vector2, text_char: String, f_size: int, text_color: Color) -> void:
	var radius: float = 10.0
	_border_canvas.draw_circle(plate_pos, radius, Color(0.06, 0.06, 0.08, 0.95))
	_border_canvas.draw_circle(plate_pos, radius, Color(0.2, 0.85, 0.85, 0.65), false, 1.5)
	
	var start_x: float = plate_pos.x - radius
	var diameter: float = radius * 2.0
	
	var font_height: float = f.get_height(f_size)
	var font_ascent: float = f.get_ascent(f_size)
	var baseline_y: float = plate_pos.y + font_ascent - (font_height / 2.0)
	
	_border_canvas.draw_string(f, Vector2(start_x, baseline_y), text_char, HORIZONTAL_ALIGNMENT_CENTER, diameter, f_size, text_color)
