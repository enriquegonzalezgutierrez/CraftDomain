# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: RoadGeneratorService
# Description: Pure Domain Service responsible for calculating and sculpting paved 
#              connecting roads and roadside streetlight placements deterministically.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the mathematical 
#   projection formulas of road layouts and roadside lamp intervals.
# - Open-Closed Principle (OCP): Extensible with new highway segments by 
#   appending vector coordinates to the _road_segments database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RoadGeneratorService
extends RefCounted

## Struct representing a fixed linear highway connecting two Points of Interest.
class RoadSegment:
	var start_point: Vector2
	var end_point: Vector2
	var road_width: float
	var lamp_interval: float
	
	func _init(p_start: Vector2, p_end: Vector2, p_width: float = 2.5, p_interval: float = 20.0) -> void:
		start_point = p_start
		end_point = p_end
		road_width = p_width
		lamp_interval = p_interval


## Symmetrical road segments connecting fixed POI coordinates (Spawn at center)
static var _road_segments: Array[RoadSegment] = [
	# Road 1: Central Spawn (0,0) -> Grand Castle (200, 200)
	RoadSegment.new(Vector2(0, 0), Vector2(200, 200), 2.5, 20.0),
	
	# Road 2: Central Spawn (0,0) -> Harbor City (-150, 0)
	RoadSegment.new(Vector2(0, 0), Vector2(-150, 0), 2.5, 20.0),
	
	# Road 3: Central Spawn (0,0) -> Steve's Cabin (300, -300)
	RoadSegment.new(Vector2(0, 0), Vector2(300, -300), 2.5, 20.0),
	
	# Road 4: Central Spawn (0,0) -> Nether Portal Outpost (-300, -300)
	RoadSegment.new(Vector2(0, 0), Vector2(-300, -300), 2.5, 20.0)
]


## Evaluates if a global 2D coordinate falls within any of the highway segments.
## Returns true if the block must be paved, false otherwise.
static func is_on_road(global_x: float, global_z: float) -> bool:
	var p := Vector2(global_x, global_z)
	
	# Skip paving over deep ocean centers or sky islands to prevent structural floating
	var distance_from_center := p.length()
	if distance_from_center < 25.0:
		return false # Safe zone around spawning sandy shoreline
		
	# ==========================================================================
	# TACTICAL BOUNDING BOX EXCLUSIONS (OCP / SOLID COMPLIANCE)
	# Terminates the road generator exactly where the outer gates/entrances
	# of the handcrafted global landmark structures begin, preventing 
	# highway pavement from breaking internal rooms or creating y+1 steps.
	# ==========================================================================
	
	# 1. Grand Castle [Center: (200, 200) | Outer boundary radius: 24]
	if abs(global_x - 200.0) <= 24.0 and abs(global_z - 200.0) <= 24.0:
		return false
		
	# 2. Steve's Settlement [Center: (300, -300) | Outer boundary radius: 20]
	if abs(global_x - 300.0) <= 20.0 and abs(global_z - (-300.0)) <= 20.0:
		return false
		
	# 3. Seaport & Galleon [Center: (-150, 0) | Outer boundary radius: 20]
	if abs(global_x - (-150.0)) <= 20.0 and abs(global_z - 0.0) <= 20.0:
		return false
		
	# 4. Nether Portal Outpost [Center: (-300, -300) | Outer boundary radius: 18]
	if abs(global_x - (-300.0)) <= 18.0 and abs(global_z - (-300.0)) <= 18.0:
		return false
		
	# --------------------------------------------------------------------------
	
	for segment: RoadSegment in _road_segments:
		var v := segment.end_point - segment.start_point
		var w := p - segment.start_point
		
		# Proportional projection factor t along the line segment
		var t := w.dot(v) / v.length_squared()
		t = clamp(t, 0.0, 1.0)
		
		var closest_point := segment.start_point + t * v
		var distance_to_segment := p.distance_to(closest_point)
		
		if distance_to_segment <= segment.road_width:
			return true
			
	return false


## Scans the chunk's boundaries and returns a list of coordinates where 
## roadside streetlights should spawn deterministically along the highway shoulders.
static func get_roadside_lamps_for_chunk(chunk_pos: Vector3i) -> Array[Vector3]:
	var lamps: Array[Vector3] = []
	var chunk_start_x := chunk_pos.x * Chunk.SIZE
	var chunk_start_z := chunk_pos.z * Chunk.SIZE
	
	for segment: RoadSegment in _road_segments:
		var segment_vector := segment.end_point - segment.start_point
		var segment_len := segment_vector.length()
		var road_dir := segment_vector.normalized()
		
		# Calculate the perpendicular offset vector (pointing to the road shoulder/arcén)
		var perpendicular := Vector2(-road_dir.y, road_dir.x).normalized()
		
		# Iterate along the segment length at regular intervals
		var current_dist := segment.lamp_interval
		while current_dist < segment_len - 15.0:
			var center_road_pos_2d := segment.start_point + (road_dir * current_dist)
			
			# Symmetrical placement: Place one lamp on each side of the road (Left & Right shoulders)
			for side: int in [-1, 1]:
				var shoulder_pos_2d := center_road_pos_2d + (perpendicular * (segment.road_width + 1.25) * float(side))
				
				# Check if the calculated 2D shoulder position falls inside the requested Chunk's grid
				var is_inside_chunk_x := shoulder_pos_2d.x >= chunk_start_x and shoulder_pos_2d.x < chunk_start_x + Chunk.SIZE
				var is_inside_chunk_z := shoulder_pos_2d.y >= chunk_start_z and shoulder_pos_2d.y < chunk_start_z + Chunk.SIZE
				
				if is_inside_chunk_x and is_inside_chunk_z:
					# Return coordinate mapping, height Y=0 is placeholder (will be dropped to ground level dynamically)
					var lamp_coord := Vector3(shoulder_pos_2d.x, 0.0, shoulder_pos_2d.y)
					lamps.append(lamp_coord)
					print("[RoadGenerator] Evaluated target shoulder coordinate for chunk %s at 2D %s" % [chunk_pos, shoulder_pos_2d])
					
			current_dist += segment.lamp_interval
			
	return lamps
