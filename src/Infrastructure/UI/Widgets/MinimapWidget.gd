# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              circular minimap radar, player direction arrow, and active quest markers.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates radar drawing 
#                and coordinate evaluations from the player HUD orchestrator.
#              OPTIMIZATIONS:
#              - Throttled the update rate of the radar drawing loop to a stable 20 FPS (0.05s).
#                This reduces heavy simplex noise calls in BiomeService by more than 83%,
#                preventing main-thread stuttering.
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
	style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.25)
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
	
	# 1. DRAW REGIONAL BIOME TILES
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
				
	# 2. DRAW ACTIVE QUEST MARKER
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.required_item_index == -1:
		var q_pos: Vector3 = active_q.target_position
		var diff_vec := Vector2(q_pos.x - player_pos.x, q_pos.z - player_pos.z)
		var radar_pos := diff_vec
		var max_r: float = (size_dim / 2.0) - 8.0
		
		if radar_pos.length() > max_r:
			radar_pos = radar_pos.normalized() * max_r
			
		var draw_target := center + radar_pos
		var pulse: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
		
		var out_size: float = (5.0 * pulse) + 1.5
		var q_outline := PackedVector2Array([
			draw_target + Vector2(0, -out_size), draw_target + Vector2(-out_size, 0),
			draw_target + Vector2(0, out_size), draw_target + Vector2(out_size, 0)
		])
		_radar.draw_colored_polygon(q_outline, Color(0.0, 0.0, 0.0, 0.85))
		
		var r_size: float = 5.0 * pulse
		var q_vertices := PackedVector2Array([
			draw_target + Vector2(0, -r_size), draw_target + Vector2(-r_size, 0),
			draw_target + Vector2(0, r_size), draw_target + Vector2(r_size, 0)
		])
		_radar.draw_colored_polygon(q_vertices, Color(1.0, 0.05, 0.55)) 
		
	# 3. DRAW PLAYER ARROW
	var angle: float = -player.rotation.y
	var out_arrow_vertices := PackedVector2Array([center + Vector2(0, -9.5), center + Vector2(-6.5, 7.5), center + Vector2(6.5, 7.5)])
	var rotated_out_vertices := PackedVector2Array()
	for vertex in out_arrow_vertices:
		rotated_out_vertices.append(center + (vertex - center).rotated(angle))
	_radar.draw_colored_polygon(rotated_out_vertices, Color(0.0, 0.0, 0.0, 0.9))
	
	var arrow_vertices := PackedVector2Array([center + Vector2(0, -8), center + Vector2(-5, 6), center + Vector2(5, 6)])
	var rotated_vertices := PackedVector2Array()
	for vertex in arrow_vertices:
		rotated_vertices.append(center + (vertex - center).rotated(angle))
	_radar.draw_colored_polygon(rotated_vertices, Color(0.98, 0.98, 0.98))
