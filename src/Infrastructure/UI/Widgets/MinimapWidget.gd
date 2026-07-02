# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for rendering the 
#              circular minimap radar, player direction arrow, and active markers.
#              COMMERCIAL UI OVERHAUL:
#              - Flawless Radial Culling: Restructured node hierarchy using 
#                CLIP_CHILDREN_ONLY on a circular StyleBox. Biome squares are 
#                now mathematically clipped, completely eliminating edge bleeding.
#              - Smooth Continuous Sliding: Replaced rigid chunk-snapping with 
#                fractional coordinate offsets. The map now scrolls fluidly 
#                (1 meter = 1 pixel) as the player walks.
#              - Holographic Compass Plates: Added floating, glassmorphic 
#                cardinal point badges (N, S, E, W) with glowing cyan borders.
#              - CRT Vignette Shading: Added concentric alpha gradients to give 
#                the radar a spherical, 3D glass lens aesthetic.
#              WARNING FIX (STRICT TYPING):
#              - Replaced implicit math inferences (`:=`) with explicit static types 
#                (`: float =`) on `chunk_center_x` and all local variables to 
#                prevent Godot's static analyzer from failing to infer types.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/MinimapWidget.gd
# ==============================================================================
class_name MinimapWidget
extends Control

var player: CharacterBody3D
var world_controller: Node3D

# Internal Layers (Separated for flawless clipping and overlays)
var _mask_panel: Panel
var _radar_canvas: Control
var _border_canvas: Control

# Throttling timer parameters
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.04 # 25 FPS radar refresh for smooth sliding

const SIZE_DIM: float = 160.0
const CENTER: Vector2 = Vector2(SIZE_DIM / 2.0, SIZE_DIM / 2.0)
const MAX_RADIUS: float = (SIZE_DIM / 2.0) - 2.0

const RADAR_BIOME_COLORS: Dictionary = {
	0: Color(0.12, 0.55, 0.82), 1: Color(0.38, 0.85, 0.28), 2: Color(0.92, 0.85, 0.35), 
	3: Color(0.48, 0.48, 0.48), 4: Color(0.98, 0.98, 0.98), 5: Color(0.18, 0.45, 0.15), 
	6: Color(0.85, 0.38, 0.22), 7: Color(0.0, 0.85, 0.85),  8: Color(0.28, 0.22, 0.15), 
	9: Color(1.0, 1.0, 1.0)
}


func _ready() -> void:
	name = "MinimapWidget"
	custom_minimum_size = Vector2(SIZE_DIM, SIZE_DIM)
	size = Vector2(SIZE_DIM, SIZE_DIM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_rendering_layers()


func _setup_rendering_layers() -> void:
	# 1. Base Mask Panel: Acts as a perfect circular stencil to clip biomes
	_mask_panel = Panel.new()
	_mask_panel.name = "ClippingMask"
	_mask_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mask_style: StyleBoxFlat = StyleBoxFlat.new()
	mask_style.bg_color = Color(0.04, 0.04, 0.06, 0.85) # Base radar background
	mask_style.set_corner_radius_all(int(SIZE_DIM / 2.0))
	mask_style.anti_aliasing = true
	_mask_panel.add_theme_stylebox_override("panel", mask_style)
	
	# This magical property ensures children (the biomes) never bleed outside the circle!
	_mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_mask_panel)
	
	# 2. Radar Canvas: Draws the moving biomes and grid (Gets clipped by parent)
	_radar_canvas = Control.new()
	_radar_canvas.name = "RadarCanvas"
	_radar_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar_canvas.draw.connect(_on_radar_draw)
	_mask_panel.add_child(_radar_canvas)
	
	# 3. Border Canvas: Draws the HUD overlays (Vignette, Compass, Pins). Unclipped!
	_border_canvas = Control.new()
	_border_canvas.name = "BorderCanvas"
	_border_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_canvas.draw.connect(_on_border_draw)
	add_child(_border_canvas)


## Restricts draw commands to a throttled framerate to optimize CPU cycles.
func update_widget() -> void:
	var delta: float = get_process_delta_time()
	_update_timer += delta
	
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		if is_instance_valid(_radar_canvas):
			_radar_canvas.queue_redraw()
		if is_instance_valid(_border_canvas):
			_border_canvas.queue_redraw()


# ==============================================================================
# LAYER 1: CLIPPED RADAR CANVAS (Biomes, Grid, Entities)
# ==============================================================================
func _on_radar_draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller): 
		return
		
	var player_pos: Vector3 = player.global_position
	
	# 1. DRAW SMOOTH-SLIDING BIOME TILES
	var grid_radius: int = 6
	var step_size: float = 16.0
	
	# Smooth offset calculation for buttery rendering (1 meter = 1 pixel)
	var chunk_center_x: float = floor(player_pos.x / 16.0) * 16.0 + 8.0
	var chunk_center_z: float = floor(player_pos.z / 16.0) * 16.0 + 8.0
	var player_offset: Vector2 = Vector2(player_pos.x - chunk_center_x, player_pos.z - chunk_center_z)
	
	# FIX: Explicit static typing on generator references
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if not is_instance_valid(generator): return
	var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
	if terrain_noise == null: return
	
	for cx: int in range(-grid_radius, grid_radius + 1):
		for cz: int in range(-grid_radius, grid_radius + 1):
			var sample_x: int = int(chunk_center_x) + (cx * 16)
			var sample_z: int = int(chunk_center_z) + (cz * 16)
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(sample_x, sample_z, terrain_noise) as BiomeService.BiomeProfile
			var biome_color: Color = RADAR_BIOME_COLORS.get(profile.biome_id, Color.BLACK)
			
			var draw_pos: Vector2 = CENTER + (Vector2(float(cx), float(cz)) * step_size) - player_offset - Vector2(step_size / 2.0, step_size / 2.0)
			var rect_target: Rect2 = Rect2(draw_pos, Vector2(step_size, step_size))
			
			# Draw the biome solid block (It gets clipped mathematically by the parent panel!)
			_radar_canvas.draw_rect(rect_target, biome_color, true)
			# Draw digital screen grid lines
			_radar_canvas.draw_rect(rect_target, Color(0.0, 0.0, 0.0, 0.12), false, 1.0)

	# 2. DRAW TACTICAL SONAR RINGS
	var grid_color: Color = Color(1.0, 1.0, 1.0, 0.08)
	_radar_canvas.draw_line(CENTER - Vector2(MAX_RADIUS, 0), CENTER + Vector2(MAX_RADIUS, 0), grid_color, 1.0)
	_radar_canvas.draw_line(CENTER - Vector2(0, MAX_RADIUS), CENTER + Vector2(0, MAX_RADIUS), grid_color, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.4, grid_color, false, 1.0)
	_radar_canvas.draw_circle(CENTER, MAX_RADIUS * 0.75, grid_color, false, 1.0)

	# 3. DRAW TACTICAL ENTITY PINS
	# FIX: Explicit static typing on children loop iterator
	for child: Node in world_controller.get_children():
		if not is_instance_valid(child):
			continue
			
		var child_pos: Vector3 = Vector3.ZERO
		var pin_color: Color = Color.WHITE
		var is_chest: bool = false
		var is_enemy: bool = false
		var is_valid_entity: bool = false
		
		if child is PassiveEntity:
			child_pos = child.global_position
			pin_color = Color(0.2, 0.85, 0.85) # Teal/Cyan NPC
			is_valid_entity = true
		elif child is HostileEntity:
			child_pos = child.global_position
			pin_color = Color(0.95, 0.15, 0.15) # Crimson Red Enemy
			is_enemy = true
			is_valid_entity = true
		elif child is ChestEntity:
			child_pos = child.global_position
			pin_color = Color(1.0, 0.82, 0.2) # Golden Chest
			is_chest = true
			is_valid_entity = true
			
		if is_valid_entity:
			var diff: Vector2 = Vector2(child_pos.x - player_pos.x, child_pos.z - player_pos.z)
			if diff.length() < MAX_RADIUS - 2.0:
				var draw_pos: Vector2 = CENTER + diff
				
				if is_chest:
					var rect: Rect2 = Rect2(draw_pos - Vector2(2, 2), Vector2(4, 4))
					_radar_canvas.draw_rect(rect, pin_color, true)
					_radar_canvas.draw_rect(rect, Color.BLACK, false, 1.0)
				elif is_enemy:
					_radar_canvas.draw_circle(draw_pos, 2.5, pin_color)
					_radar_canvas.draw_circle(draw_pos, 2.5, Color.BLACK, false, 1.0)
				else:
					_radar_canvas.draw_circle(draw_pos, 2.0, pin_color)
					_radar_canvas.draw_circle(draw_pos, 2.0, Color.BLACK, false, 1.0)

	# 4. DRAW STREETLIGHT POSTS
	var streetlight_service: StreetlightService = world_controller.get("_streetlight_service") as StreetlightService
	if is_instance_valid(streetlight_service):
		var coords: Array = streetlight_service.get("_streetlight_coords") as Array
		for coord_val: Variant in coords:
			var coord: Vector3i = coord_val as Vector3i
			var diff: Vector2 = Vector2(float(coord.x) - player_pos.x, float(coord.z) - player_pos.z)
			if diff.length() < MAX_RADIUS - 2.0:
				var draw_pos: Vector2 = CENTER + diff
				var rect: Rect2 = Rect2(draw_pos - Vector2(1.5, 1.5), Vector2(3, 3))
				_radar_canvas.draw_rect(rect, Color(1.0, 0.55, 0.0), true)


# ==============================================================================
# LAYER 2: OVERLAY BORDER CANVAS (Vignette, Compass Plates, Player)
# ==============================================================================
func _on_border_draw() -> void:
	if not is_instance_valid(player):
		return
	
	var player_pos: Vector3 = player.global_position
	
	# 1. DRAW CRT LENS VIGNETTE SHADOWS
	# Draws concentric alpha rings to make the edges of the radar look like curved glass
	for i: int in range(12):
		var r: float = MAX_RADIUS - float(i)
		var alpha: float = (float(12 - i) / 12.0) * 0.35
		_border_canvas.draw_circle(CENTER, r, Color(0.04, 0.04, 0.06, alpha), false, 1.5)

	# 2. DRAW GLASSMORPHIC HARD BORDER
	_border_canvas.draw_circle(CENTER, SIZE_DIM / 2.0, Color(0.1, 0.1, 0.12, 0.5), false, 6.0)
	_border_canvas.draw_circle(CENTER, SIZE_DIM / 2.0, Color(0.3, 0.3, 0.35, 0.9), false, 2.0)

	# 3. DRAW HOLOGRAPHIC COMPASS PLATES (N, S, E, W)
	var default_font: Font = get_theme_font("font")
	var compass_color: Color = Color(1.0, 0.85, 0.2) # High contrast Gold
	var f_size: int = 11
	var offset: float = (SIZE_DIM / 2.0) - 1.0 # Pins sit exactly on the border ring
	
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y - offset), tr("DIR_N").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x, CENTER.y + offset), tr("DIR_S").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x + offset, CENTER.y), tr("DIR_E").left(1).to_upper(), f_size, compass_color)
	_draw_holographic_compass_plate(default_font, Vector2(CENTER.x - offset, CENTER.y), tr("DIR_W").left(1).to_upper(), f_size, compass_color)

	# 4. DRAW ACTIVE QUEST MARKER (Glowing Magenta Diamond)
	var active_q: Quest = QuestService.get_active_quest() as Quest
	if active_q != null and active_q.required_item_index == -1:
		var q_pos: Vector3 = active_q.target_position
		var diff_vec: Vector2 = Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos: Vector2 = diff_vec
		
		# Clamp strictly to the outer ring if far away
		if radar_pos.length() > MAX_RADIUS - 4.0:
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
		_border_canvas.draw_polyline(diamond_points, Color.BLACK, 1.5)

	# 5. DRAW PLAYER ARROW (Always dead center)
	_border_canvas.draw_circle(CENTER, 4.0, Color(0.2, 0.2, 0.2, 0.6)) # Shadow
	_border_canvas.draw_circle(CENTER, 3.0, Color.WHITE)
	_border_canvas.draw_circle(CENTER, 3.0, Color.BLACK, false, 1.0)
	
	var look_angle: float = -player.rotation.y - (PI / 2.0)
	var arrow_length: float = 12.0
	var arrow_end: Vector2 = CENTER + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
	
	_border_canvas.draw_line(CENTER, arrow_end, Color.BLACK, 3.5) # Arrow outline
	_border_canvas.draw_line(CENTER, arrow_end, Color.WHITE, 1.5) # Arrow core


## Private Helper: Draws an incredibly polished glowing circular plate under each compass letter
func _draw_holographic_compass_plate(f: Font, plate_pos: Vector2, text_char: String, f_size: int, text_color: Color) -> void:
	# 1. Dark backing plate to occlude the map underneath
	_border_canvas.draw_circle(plate_pos, 10.0, Color(0.06, 0.06, 0.08, 0.95))
	# 2. Glowing outer cian outline
	_border_canvas.draw_circle(plate_pos, 10.0, Color(0.2, 0.85, 0.85, 0.65), false, 1.5)
	# 3. Center localized letter
	_border_canvas.draw_string(f, plate_pos + Vector2(0.0, 4.0), text_char, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size, text_color)
