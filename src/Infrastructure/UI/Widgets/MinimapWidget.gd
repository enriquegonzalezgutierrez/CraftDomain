# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              circular minimap radar, player direction arrow, and active quest markers.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates radar drawing 
#                and coordinate evaluations from the player HUD orchestrator.
#              UX TACTICAL OVERHAUL (PREMIUM HUD REDESIGN):
#              - Implemented strict mathematical radial culling. Biome tiles now 
#                clip flawlessly inside the circular border, preventing ugly block overflows.
#              - Added a tactical radar grid reticle with crosshairs and concentric 
#                sonar rings.
#              - Implemented floating circular holographic plates for cardinal points 
#                (N, S, E, W/O) with glowing neon cyan borders for absolute readability.
#              - Added a soft peripheral CRT-style vignette shading on map edges.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/MinimapWidget.gd
# ==============================================================================
class_name MinimapWidget
extends Panel

var player: CharacterBody3D
var world_controller: Node3D
var _radar: Control

# Throttling timer parameters
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.05 # Limit radar drawing to 20 FPS for extreme performance

const RADAR_BIOME_COLORS = {
	0: Color(0.12, 0.55, 0.82), 1: Color(0.38, 0.85, 0.28), 2: Color(0.92, 0.85, 0.35), 
	3: Color(0.48, 0.48, 0.48), 4: Color(0.98, 0.98, 0.98), 5: Color(0.18, 0.45, 0.15), 
	6: Color(0.85, 0.38, 0.22), 7: Color(0.0, 0.85, 0.85),  8: Color(0.28, 0.22, 0.15), 
	9: Color(1.0, 1.0, 1.0)
}


func _ready() -> void:
	name = "MinimapWidget"
	custom_minimum_size = Vector2(150, 150)
	
	var style := StyleBoxFlat.new()
	style.corner_detail = 8
	style.set_corner_radius_all(75) 
	style.bg_color = Color(0.04, 0.04, 0.06, 0.65) # Semi-translucent backing
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.25, 0.25, 0.3, 0.9)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	add_theme_stylebox_override("panel", style)
	
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	_radar = Control.new()
	_radar.name = "RadarCanvas"
	_radar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_on_radar_draw)
	add_child(_radar)


## Restricts draw commands to a throttled framerate to optimize CPU cycles.
func update_widget() -> void:
	var delta := get_process_delta_time()
	_update_timer += delta
	
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		if is_instance_valid(_radar):
			_radar.queue_redraw()


func _on_radar_draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller): 
		return
		
	var size_dim: float = 150.0
	var center := Vector2(size_dim / 2.0, size_dim / 2.0)
	var player_pos := player.global_position
	var grid_radius: int = 4
	var step_size: float = 16.0
	var max_r: float = (size_dim / 2.0) - 5.0
	
	# 1. DRAW REGIONAL BIOME TILES (WITH STRICT NEON CLIPPING SAFETY)
	for x: int in range(-grid_radius, grid_radius + 1):
		for z: int in range(-grid_radius, grid_radius + 1):
			var sample_x: int = int(round(player_pos.x)) + (x * 16)
			var sample_z: int = int(round(player_pos.z)) + (z * 16)
			
			var profile := BiomeService.evaluate_coordinate(sample_x, sample_z, world_controller.generator._terrain_noise) as BiomeService.BiomeProfile
			var biome_color: Color = RADAR_BIOME_COLORS[profile.biome_id]
			
			var draw_pos := center + Vector2(float(x), float(z)) * step_size - Vector2(step_size / 2.0, step_size / 2.0)
			var rect_target := Rect2(draw_pos, Vector2(step_size - 1.0, step_size - 1.0))
			
			# STRICT CLIPPING CHECK: Verify the tile center sits completely inside the circular radar
			var tile_center := draw_pos + Vector2(step_size / 2.0, step_size / 2.0)
			if tile_center.distance_to(center) < max_r - 2.0:
				_radar.draw_rect(rect_target, biome_color, true)
				# Draw subtle dark borders to create a cohesive digital screen grid!
				_radar.draw_rect(rect_target, Color(0.0, 0.0, 0.0, 0.12), false, 1.0)
				
	# ==========================================================================
	# TACTICAL RETICLE GRID LINES & SONAR RINGS
	# Creates a premium sci-fi, high-tech military radar look.
	# ==========================================================================
	var grid_color := Color(1.0, 1.0, 1.0, 0.07) # Faint translucent white
	_radar.draw_line(center - Vector2(max_r, 0), center + Vector2(max_r, 0), grid_color, 1.0)
	_radar.draw_line(center - Vector2(0, max_r), center + Vector2(0, max_r), grid_color, 1.0)
	_radar.draw_circle(center, max_r * 0.35, grid_color, false, 1.0) # Inner Sonar Ring
	_radar.draw_circle(center, max_r * 0.70, grid_color, false, 1.0) # Mid Sonar Ring
	# ==========================================================================
				
	# ==========================================================================
	# TACTICAL PROXIMITY ENTITY & CHEST SCANNER
	# Identifies nearby passive villagers, hostile zombies, and gold loot chests.
	# ==========================================================================
	# FIX: Explicit static typing `Node` on children loop iterator
	for child: Node in world_controller.get_children():
		if not is_instance_valid(child):
			continue
			
		var child_pos := Vector3.ZERO
		var pin_color := Color.WHITE
		var is_chest := false
		var is_enemy := false
		var is_valid_entity := false
		
		if child is PassiveEntity:
			child_pos = child.global_position
			pin_color = Color(0.2, 0.85, 0.85) # Teal/Cyan NPC Dot
			is_valid_entity = true
		elif child is HostileEntity:
			child_pos = child.global_position
			pin_color = Color(0.95, 0.15, 0.15) # Crimson Red Enemy Dot
			is_enemy = true
			is_valid_entity = true
		elif child is ChestEntity:
			child_pos = child.global_position
			pin_color = Color(1.0, 0.82, 0.2) # Golden Loot Chest Square
			is_chest = true
			is_valid_entity = true
			
		if is_valid_entity:
			var diff := Vector2(child_pos.x - player_pos.x, child_pos.z - player_pos.z)
			
			# Render the pin ONLY if the target is within the radar's visual range
			if diff.length() < max_r - 4.0:
				var draw_pos := center + diff
				
				if is_chest:
					# Gold Chest: Draw a 4x4 square with black outline
					var rect := Rect2(draw_pos - Vector2(2, 2), Vector2(4, 4))
					_radar.draw_rect(rect, pin_color, true)
					_radar.draw_rect(rect, Color.BLACK, false, 1.0)
				elif is_enemy:
					# Zombie: Draw a 4px Red dot with outline
					_radar.draw_circle(draw_pos, 2.5, pin_color)
					_radar.draw_circle(draw_pos, 2.5, Color.BLACK, false, 1.0)
				else:
					# NPC: Draw a 4px Teal dot with outline
					_radar.draw_circle(draw_pos, 2.0, pin_color)
					_radar.draw_circle(draw_pos, 2.0, Color.BLACK, false, 1.0)
	# ==========================================================================

	# ==========================================================================
	# PROCEDURAL STREETLIGHTS SCANNER
	# Renders permanent warm orange dots showing lighting posts inside villages.
	# ==========================================================================
	var streetlight_service: StreetlightService = world_controller.get("_streetlight_service") as StreetlightService
	if is_instance_valid(streetlight_service):
		var coords: Array = streetlight_service.get("_streetlight_coords") as Array
		# FIX: Explicit static typing `Variant` on raw array key iterator
		for coord_val: Variant in coords:
			var coord := coord_val as Vector3i
			var diff := Vector2(float(coord.x) - player_pos.x, float(coord.z) - player_pos.z)
			
			# Render the pin ONLY if the streetlight is within the radar range
			if diff.length() < max_r - 4.0:
				var draw_pos := center + diff
				# Draw a small 3x3 orange square representing lighting posts!
				var rect := Rect2(draw_pos - Vector2(1.5, 1.5), Vector2(3, 3))
				_radar.draw_rect(rect, Color(1.0, 0.55, 0.0), true)
	# ==========================================================================

	# 2. DRAW ACTIVE QUEST MARKER (Magenta/Pink Diamond)
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.required_item_index == -1:
		var q_pos: Vector3 = active_q.target_position
		var diff_vec := Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos := diff_vec
		
		# Clamp to edge if the quest is far away
		if radar_pos.length() > max_r:
			radar_pos = radar_pos.normalized() * max_r
			
		var draw_target := center + radar_pos
		var pulse_radius: float = 8.0 + abs(sin(Time.get_ticks_msec() / 250.0)) * 6.0
		
		# Render glowing pulsing ring
		_radar.draw_circle(draw_target, pulse_radius, Color(1.0, 0.05, 0.55, 0.18))
		
		# Draw the diamond shape
		var diamond_points := PackedVector2Array([
			draw_target + Vector2(0, -5),
			draw_target + Vector2(5, 0),
			draw_target + Vector2(0, 5),
			draw_target + Vector2(-5, 0)
		])
		_radar.draw_colored_polygon(diamond_points, Color(1.0, 0.05, 0.55))
		_radar.draw_polyline(diamond_points, Color.BLACK, 1.2)
		
	# ==========================================================================
	# VIGNETTE SHADOW EFFECT (Lens shadow curves)
	# Softly shades the perimeter of the radar to mimic CRT lens glass bending
	# ==========================================================================
	for i: int in range(6):
		var r: float = max_r - float(i)
		var alpha: float = float(i) / 6.0
		_radar.draw_circle(center, r, Color(0.04, 0.04, 0.06, 0.18 * (1.0 - alpha)), false, 1.5)
	# ==========================================================================

	# ==========================================================================
	# HOLOGRAPHIC COMPASS PLATES (Localized dynamic N, S, E, W/O)
	# Draws small circular plates with glowing cyan outlines for perfect legibility.
	# ==========================================================================
	var default_font: Font = get_theme_font("font")
	var compass_color := Color(1.0, 0.85, 0.2) # High contrast Gold
	var compass_font_size := 11
	
	# A. North (N / N)
	var char_n: String = tr("DIR_N").left(1).to_upper()
	var pos_n := Vector2(center.x, center.y - max_r + 6)
	_draw_holographic_compass_plate(default_font, pos_n, char_n, compass_font_size, compass_color)
	
	# B. South (S / S)
	var char_s: String = tr("DIR_S").left(1).to_upper()
	var pos_s := Vector2(center.x, center.y + max_r - 6)
	_draw_holographic_compass_plate(default_font, pos_s, char_s, compass_font_size, compass_color)
	
	# C. East (E / E)
	var char_e: String = tr("DIR_E").left(1).to_upper()
	var pos_e := Vector2(center.x + max_r - 6, center.y)
	_draw_holographic_compass_plate(default_font, pos_e, char_e, compass_font_size, compass_color)
	
	# D. West (W / O)
	var char_w: String = tr("DIR_W").left(1).to_upper()
	var pos_w := Vector2(center.x - max_r + 6, center.y)
	_draw_holographic_compass_plate(default_font, pos_w, char_w, compass_font_size, compass_color)
	# ==========================================================================
				
	# 3. DRAW Player Pointer
	_radar.draw_circle(center, 3.5, Color.WHITE)
	_radar.draw_circle(center, 3.5, Color.BLACK, false, 1.0)
	
	var look_angle := -player.rotation.y - (PI / 2.0)
	var arrow_length := 11.0
	var arrow_end := center + Vector2(cos(look_angle), sin(look_angle)) * arrow_length
	_radar.draw_line(center, arrow_end, Color.WHITE, 2.0)
	_radar.draw_line(center, arrow_end, Color.BLACK, 3.0)


## Private Helper: Draws an incredibly polished glowing circular plate under each compass letter
func _draw_holographic_compass_plate(f: Font, plate_pos: Vector2, text_char: String, f_size: int, text_color: Color) -> void:
	# 1. Dark backing plate
	_radar.draw_circle(plate_pos, 9.0, Color(0.06, 0.06, 0.08, 0.9))
	# 2. Glowing outer cian outline
	_radar.draw_circle(plate_pos, 9.0, Color(0.2, 0.85, 0.85, 0.55), false, 1.0)
	# 3. Center letter
	_radar.draw_string(f, plate_pos + Vector2(0.0, 4.0), text_char, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size, text_color)
