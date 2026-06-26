# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              circular minimap radar, player direction arrow, and active quest markers.
#              SOLID COMPLIANCE: Strictly satisfies the Single Responsibility 
#              Principle (SRP) by isolating map drawing from the main HUD class.
#              Eliminated dynamic string compilation in favor of clean native GDScript.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/MinimapWidget.gd
# ==============================================================================
class_name MinimapWidget
extends Panel

# Dependencies injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

var _radar: Control

# Biome color mappings duplicated here for self-containment
const RADAR_BIOME_COLORS = {
	0: Color(0.12, 0.55, 0.82), # Ocean
	1: Color(0.38, 0.85, 0.28), # Warp Plateau
	2: Color(0.92, 0.85, 0.35), # Golden Bazaar
	3: Color(0.48, 0.48, 0.48), # Craggy Mines
	4: Color(0.98, 0.98, 0.98), # Frostbite Glaciers
	5: Color(0.18, 0.45, 0.15), # Redwood Forest
	6: Color(0.85, 0.38, 0.22), # Badlands
	7: Color(0.0, 0.85, 0.85),  # Neon Ruins
	8: Color(0.28, 0.22, 0.15), # Swamp of Sighs
	9: Color(1.0, 1.0, 1.0)     # Cloud Kingdom
}

func _ready() -> void:
	name = "MinimapWidget"
	custom_minimum_size = Vector2(150, 150)
	
	# Circular glassmorphic frame
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
	add_theme_stylebox_override("panel", style)
	
	# Enable clipping so the radar grid is perfectly bound to the circle
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	# Instantiates the clean native drawing canvas
	_radar = Control.new()
	_radar.name = "RadarCanvas"
	_radar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_on_radar_draw)
	add_child(_radar)

func update_widget() -> void:
	if is_instance_valid(_radar):
		_radar.queue_redraw()

## Pure Native Draw routine: No more confusable variables or dynamic string compilations!
func _on_radar_draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var size_dim: float = 150.0
	var center := Vector2(size_dim / 2.0, size_dim / 2.0)
	var player_pos := player.global_position
	var grid_radius: int = 4
	var step_size: float = 16.0
	
	# 1. DRAW REGIONAL BIOME TILES (9x9 Local Scan Grid)
	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			var sample_x: int = int(round(player_pos.x)) + (x * 16)
			var sample_z: int = int(round(player_pos.z)) + (z * 16)
			
			var profile := BiomeService.evaluate_coordinate(sample_x, sample_z, world_controller.generator._terrain_noise)
			var biome_color: Color = RADAR_BIOME_COLORS[profile.biome_id]
			
			var draw_pos := center + Vector2(float(x), float(z)) * step_size - Vector2(step_size / 2.0, step_size / 2.0)
			var rect_target := Rect2(draw_pos, Vector2(step_size - 1.0, step_size - 1.0))
			
			if draw_pos.distance_to(center) < (size_dim / 2.0) - 5.0:
				_radar.draw_rect(rect_target, biome_color, true)
				
	# 2. DRAW HIGH-CONTRAST OUTLINED ACTIVE QUEST MARKER (Skyrim style navigation)
	var active_q := QuestService.get_active_quest()
	if active_q != null:
		var q_pos: Vector3 = active_q.target_position
		var diff_vec := Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos := diff_vec
		var max_r: float = (size_dim / 2.0) - 8.0
		
		# Clamp destination star to the compass rim if it lies outside local view distance
		if radar_pos.length() > max_r:
			radar_pos = radar_pos.normalized() * max_r
			
		var draw_target := center + radar_pos
		var pulse: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
		
		# A. Outlined Backing (Slightly larger black shape)
		var out_size: float = (5.0 * pulse) + 1.5
		var q_outline := PackedVector2Array([
			draw_target + Vector2(0, -out_size),
			draw_target + Vector2(-out_size, 0),
			draw_target + Vector2(0, out_size),
			draw_target + Vector2(out_size, 0)
		])
		_radar.draw_colored_polygon(q_outline, Color(0.0, 0.0, 0.0, 0.85))
		
		# B. Inner Vibrant Hot-Pink Diamond
		var r_size: float = 5.0 * pulse
		var q_vertices := PackedVector2Array([
			draw_target + Vector2(0, -r_size),
			draw_target + Vector2(-r_size, 0),
			draw_target + Vector2(0, r_size),
			draw_target + Vector2(r_size, 0)
		])
		_radar.draw_colored_polygon(q_vertices, Color(1.0, 0.05, 0.55)) # Hot Pink (Universal contrast)
		
	# 3. DRAW HIGH-CONTRAST OUTLINED PLAYER ARROW (Rotates dynamically)
	var angle: float = -player.rotation.y
	
	# A. Black outline backing arrow
	var out_arrow_vertices := PackedVector2Array([
		center + Vector2(0, -9.5),
		center + Vector2(-6.5, 7.5),
		center + Vector2(6.5, 7.5)
	])
	var rotated_out_vertices := PackedVector2Array()
	for vertex in out_arrow_vertices:
		var relative_vec := vertex - center
		var rotated_vec := relative_vec.rotated(angle)
		rotated_out_vertices.append(center + rotated_vec)
	_radar.draw_colored_polygon(rotated_out_vertices, Color(0.0, 0.0, 0.0, 0.9))
	
	# B. Inner crisp white arrow on top
	var arrow_vertices := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(-5, 6),
		center + Vector2(5, 6)
	])
	var rotated_vertices := PackedVector2Array()
	for vertex in arrow_vertices:
		var relative_vec := vertex - center
		var rotated_vec := relative_vec.rotated(angle)
		rotated_vertices.append(center + rotated_vec)
	_radar.draw_colored_polygon(rotated_vertices, Color(0.98, 0.98, 0.98))
