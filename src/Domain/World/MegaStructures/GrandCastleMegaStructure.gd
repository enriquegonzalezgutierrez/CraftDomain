# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/GrandCastleMegaStructure.gd
# Description: Handcrafted two-story colossal fortress.
#              Provides structured multi-chunk medieval citadel parameters (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GrandCastleMegaStructure
extends IMegaStructure

# --- PERIMETER & BASELINE GEOMETRY CONSTANTS ---
const BASE_ALTITUDE_Y: int = 12           # Flat mountain baseline floor
const CASTLE_WALL_RADIUS: int = 24        # Expanded 48x48 outer wall footprint
const KEEP_WIDTH_HALF: int = 12           # Keep width limit (X: 188 to 212)
const KEEP_LENGTH_HALF: int = 12          # Keep length limit (Z: 182 to 206)
const CORNER_TOWER_RADIUS: int = 4        # 8x8 Cylindrical towers

# --- OUTER RAMPARTS & VERTICAL LEVELS (RELATIVE TO BASELINE Y) ---
const RAMPART_MAX_LEVEL: int = 7          # Outer defense walls height limit (Y=19)
const RAMPART_WALKWAY_LEVEL: int = 6      # Outer defense walkway floor (Y=18)
const TOWER_MAX_LEVEL: int = 14           # High-precision tower battlements (Y=26)
const TOWER_FLOOR_A: int = 6              # Intermediate tower floor 1 (Y=18)
const TOWER_FLOOR_B: int = 11             # Intermediate tower floor 2 (Y=23)

# --- INTERNAL KEEP ROOM CONSTANTS (RELATIVE TO BASELINE Y) ---
const KEEP_MAX_LEVEL: int = 17            # Absolute keep roof-deck height (Y=29)
const LEVEL_MEZZANINE_FLOOR: int = 6      # Mezzanine floor divider Y level (Y=18)
const LEVEL_ROOFTOP_SLAB: int = 13        # Roof slab platform Y level (Y=25)

# --- INNER DESIGN SEGREGATION CONSTANTS ---
const THRONE_HALL_LIMIT_X: int = 6        # Double-height Throne chamber width (X: 194 to 206)
const PARTITION_WALL_LIMIT_X: int = 7     # Symmetrical side rooms division wall


func _init() -> void:
	global_center = Vector2i(200, 200) 
	bounds_size = Vector2i(60, 60)


## Concrete Contract: Returns the landmark's friendly name
func get_name() -> String:
	return "STRUCTURE_GRAND_CASTLE"


## Concrete Contract: Sculpting pipeline executed by the chunk mesher threads
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var center_x: int = global_center.x
	var center_z: int = global_center.y
	
	var min_x: int = center_x - floori(float(bounds_size.x) / 2.0)
	var max_x: int = center_x + floori(float(bounds_size.x) / 2.0)
	var min_z: int = center_z - floori(float(bounds_size.y) / 2.0)
	var max_z: int = center_z + floori(float(bounds_size.y) / 2.0)
	
	for gx: int in range(min_x, max_x + 1):
		for gz: int in range(min_z, max_z + 1):
			var dist_x: int = abs(gx - center_x)
			var dist_z: int = abs(gz - center_z)
			
			var lx: int = gx - offset.x
			var lz: int = gz - offset.z
			
			# ==================================================================
			# PASS 1: FLATTEN MOUNTAIN BASELINE & FORCE FLAT FLOORS
			# ==================================================================
			if dist_x <= CASTLE_WALL_RADIUS and dist_z <= CASTLE_WALL_RADIUS:
				for gy: int in range(BASE_ALTITUDE_Y + 1, 32):
					var ly: int = gy - offset.y
					if chunk.is_within_bounds(lx, ly, lz):
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
						
			for gy: int in range(0, BASE_ALTITUDE_Y + 1):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < BASE_ALTITUDE_Y:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy == BASE_ALTITUDE_Y:
						if abs(gx - center_x) <= 2 and gz >= center_z + CASTLE_WALL_RADIUS:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						elif dist_x < KEEP_WIDTH_HALF and dist_z < KEEP_LENGTH_HALF:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.GRASS)

			# ==================================================================
			# PASS 2: SECURE OUTER DEFENSE WALLS
			# ==================================================================
			var is_wall_border: bool = (dist_x == CASTLE_WALL_RADIUS and dist_z <= CASTLE_WALL_RADIUS) or (dist_z == CASTLE_WALL_RADIUS and dist_x <= CASTLE_WALL_RADIUS)
			if is_wall_border:
				var is_gate: bool = (gz == center_z + CASTLE_WALL_RADIUS) and (dist_x <= 3)
				for wy: int in range(1, RAMPART_MAX_LEVEL + 2):
					if is_gate and wy <= 5: 
						continue
						
					if wy == RAMPART_MAX_LEVEL + 1 and (gx + gz) % 2 == 0:
						continue
					set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y + wy, gz, BlockType.Type.STONE)

			# ==================================================================
			# PASS 3: CYLINDRICAL CORNER DEFENSE TOWERS
			# ==================================================================
			var is_in_tower := false
			var tx: int = 0
			var tz: int = 0
			
			if abs(gx - (center_x - CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS and abs(gz - (center_z - CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS:
				is_in_tower = true; tx = center_x - CASTLE_WALL_RADIUS; tz = center_z - CASTLE_WALL_RADIUS
			elif abs(gx - (center_x + CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS and abs(gz - (center_z - CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS:
				is_in_tower = true; tx = center_x + CASTLE_WALL_RADIUS; tz = center_z - CASTLE_WALL_RADIUS
			elif abs(gx - (center_x - CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS and abs(gz - (center_z + CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS:
				is_in_tower = true; tx = center_x - CASTLE_WALL_RADIUS; tz = center_z + CASTLE_WALL_RADIUS
			elif abs(gx - (center_x + CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS and abs(gz - (center_z + CASTLE_WALL_RADIUS)) <= CORNER_TOWER_RADIUS:
				is_in_tower = true; tx = center_x + CASTLE_WALL_RADIUS; tz = center_z + CASTLE_WALL_RADIUS
				
			if is_in_tower:
				var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
				if t_dist <= float(CORNER_TOWER_RADIUS):
					for wy: int in range(1, TOWER_MAX_LEVEL + 2):
						var current_y: int = BASE_ALTITUDE_Y + wy
						var is_tower_wall: bool = t_dist > float(CORNER_TOWER_RADIUS) - 1.5
						if is_tower_wall:
							if wy == TOWER_MAX_LEVEL + 1 and (gx + gz) % 2 == 0: 
								continue
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
						else:
							if wy == TOWER_FLOOR_A or wy == TOWER_FLOOR_B:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 4: COLOSSAL TWO-STORY CENTRAL KEEP
			# ==================================================================
			var keep_center_z: int = center_z - 6 
			var keep_dist_x: int = abs(gx - center_x)
			var keep_dist_z: int = abs(gz - keep_center_z)
			
			if keep_dist_x <= KEEP_WIDTH_HALF and keep_dist_z <= KEEP_LENGTH_HALF:
				var is_keep_wall: bool = (keep_dist_x == KEEP_WIDTH_HALF or keep_dist_z == KEEP_LENGTH_HALF)
				var is_keep_gate: bool = (gz == keep_center_z + KEEP_LENGTH_HALF) and (keep_dist_x <= 3)
				
				for wy: int in range(1, KEEP_MAX_LEVEL + 1):
					var current_y: int = BASE_ALTITUDE_Y + wy
					
					if is_keep_wall:
						if is_keep_gate and wy <= 5:
							continue 
							
						var is_window: bool = (wy == 3 or wy == 11) and ((keep_dist_x == KEEP_WIDTH_HALF and gz % 4 == 0) or (keep_dist_z == KEEP_LENGTH_HALF and gx % 4 == 0))
						if is_window and not is_keep_gate:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					else:
						# ======================================================
						# INTERNAL 3D ROOM DESIGN PIPELINE
						# ======================================================
						var is_throne_hall_core: bool = (keep_dist_x <= THRONE_HALL_LIMIT_X)
						
						if is_throne_hall_core:
							if wy <= LEVEL_MEZZANINE_FLOOR - 1:
								if keep_dist_x <= 1 and gz >= keep_center_z - KEEP_LENGTH_HALF + 3:
									if wy == 1:
										set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y, gz, BlockType.Type.RED_SAND)
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								elif gx == center_x and gz == keep_center_z - KEEP_LENGTH_HALF + 2:
									if wy == 1: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									elif wy == 2: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
									elif wy == 3: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.NEON_MAGENTA)
									elif wy == 4: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLOWSTONE)
									else: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								elif gz >= 185 and gz <= 196:
									if gx >= 189 and gx <= 191:
										var step_req: int = floori(float(196 - gz) / 2.0) + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									elif gx >= 209 and gx <= 211:
										var step_req: int = floori(float(196 - gz) / 2.0) + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								elif keep_dist_x == 5 and (gz == keep_center_z or gz == keep_center_z + 4):
									if wy == 1 or wy == 5:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.NEON_CYAN)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							
							elif wy == LEVEL_MEZZANINE_FLOOR:
								var is_stair_landing: bool = (gx >= 189 and gx <= 191 and gz >= 185 and gz <= 187) or (gx >= 209 and gx <= 211 and gz >= 185 and gz <= 187)
								var is_open_balcony: bool = (gx >= 192 and gx <= 208) and (gz >= 188)
								
								if is_stair_landing or is_open_balcony:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
									
							elif wy <= LEVEL_ROOFTOP_SLAB - 1:
								var is_railing: bool = (wy == 7) and (keep_dist_x == 8 and gz >= 188)
								var is_roof_stair: bool = (gz == keep_center_z - KEEP_LENGTH_HALF + 3) and (gx >= 189 and gx <= 194)
								
								if is_railing:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_roof_stair:
									var step_req: int = 195 - gx
									if (wy - 6) <= step_req:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							elif wy == LEVEL_ROOFTOP_SLAB:
								var is_roof_hatch: bool = (gx >= 189 and gx <= 190) and (gz == keep_center_z - KEEP_LENGTH_HALF + 3)
								if is_roof_hatch:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
						else:
							var is_partition_wall: bool = (keep_dist_x == PARTITION_WALL_LIMIT_X)
							if is_partition_wall:
								var is_door_opening: bool = (gz == keep_center_z) and ((wy >= 1 and wy <= 3) or (wy >= 7 and wy <= 9))
								if is_door_opening:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								if wy <= LEVEL_MEZZANINE_FLOOR - 1: 
									var is_wing_divider: bool = (gz == 194)
									if is_wing_divider:
										if keep_dist_x == 9 and wy <= 3:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										
								elif wy == LEVEL_MEZZANINE_FLOOR:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								elif wy <= LEVEL_ROOFTOP_SLAB - 1:
									var is_upper_divider: bool = (gz == 194)
									
									if is_upper_divider:
										var is_room_door: bool = (gx == 190 or gx == 210) and wy <= 9
										if is_room_door:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										if gx < center_x and gz < 194:
											var is_bed_frame: bool = (gx >= 189 and gx <= 190) and (gz >= 185 and gz <= 187) and wy == 7
											var is_bed_pillow: bool = (gx >= 189 and gx <= 190) and (gz == 185) and wy == 8
											
											if is_bed_frame:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
											elif is_bed_pillow:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.CLOUD)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
												
										elif gx > center_x and gz < 194:
											var is_pedestal: bool = (gx == 210 and gz == 185) and wy == 7
											if is_pedestal:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
												
										else:
											var is_council_table: bool = (gx >= 208 and gx <= 210) and (gz >= 198 and gz <= 201) and wy == 7
											if is_council_table:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										
								elif wy == LEVEL_ROOFTOP_SLAB:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 5: CONSTRUCT TRANSIENT ROOFTOP DECK & SKY WATCH-DOME
			# ==================================================================
			if keep_dist_x <= KEEP_WIDTH_HALF and keep_dist_z <= KEEP_LENGTH_HALF:
				var is_roof_edge: bool = (keep_dist_x == KEEP_WIDTH_HALF or keep_dist_z == KEEP_LENGTH_HALF)
				if is_roof_edge:
					for wy: int in range(14, 18):
						var current_y: int = BASE_ALTITUDE_Y + wy
						if wy == 14 and (gx + gz) % 2 == 0:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
				else:
					for wy: int in range(14, 18):
						var current_y: int = BASE_ALTITUDE_Y + wy
						var is_canopy_vbox: bool = (keep_dist_x == 3 and keep_dist_z == 3)
						if is_canopy_vbox and wy <= 16:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
						elif keep_dist_x <= 3 and keep_dist_z <= 3 and wy == 17:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
						elif not is_canopy_vbox:
							if wy >= 14:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)


## Concrete Contract: Dispatches inhabitants and interactive props strictly inside their chunk grids
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	var ground_y := float(BASE_ALTITUDE_Y + 1) # Y=13.0
	
	if chunk_pos.x == 12 and chunk_pos.z == 12:
		# Symmetrical gate guard coordinates computed dynamically from active center
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x - 3) + 0.5, ground_y, float(global_center.y + CASTLE_WALL_RADIUS) + 0.5)})
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x + 2) + 0.5, ground_y, float(global_center.y + CASTLE_WALL_RADIUS) + 0.5)})
		
		# Symmetrical courtyard streetlights
		entities.append({"mob_id": 202, "pos": Vector3(float(global_center.x - 4) + 0.5, ground_y, float(global_center.y + 18) + 0.5)})
		entities.append({"mob_id": 202, "pos": Vector3(float(global_center.x + 3) + 0.5, ground_y, float(global_center.y + 18) + 0.5)})
		
		# Courtyard campfire
		entities.append({"mob_id": 203, "pos": Vector3(float(global_center.x - 6) + 0.5, ground_y, float(global_center.y + 12) + 0.5)})
		
	elif chunk_pos.x == 12 and chunk_pos.z == 11:
		# Imperial throne guards (Ground Floor, Y=13.0)
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x - 3) + 0.5, ground_y, float(global_center.y - 15) + 0.5)})
		entities.append({"mob_id": 102, "pos": Vector3(float(global_center.x + 2) + 0.5, ground_y, float(global_center.y - 15) + 0.5)})
		
		# The Ancestral Mayor sitting in front of his throne
		entities.append({"mob_id": 100, "pos": Vector3(float(global_center.x) + 0.5, ground_y + 1.0, float(global_center.y - 14) + 0.5)})

	elif chunk_pos.x == 13 and chunk_pos.z == 11:
		# Elevated Royal Treasury (Floor 2, Y = 19.0)
		var treasury_y := float(BASE_ALTITUDE_Y + 7.5) # Y=19.5
		entities.append({"mob_id": 102, "pos": Vector3(208.5, treasury_y, 188.5)})
		
		# Royal Loot Chest (Y=20.0, resting on the brick pedestal)
		entities.append({"mob_id": 200, "pos": Vector3(210.5, treasury_y + 0.5, 185.5)})
		
	elif chunk_pos.x == 11 and chunk_pos.z == 11:
		# Sleeping guard in barracks
		entities.append({"mob_id": 102, "pos": Vector3(191.5, ground_y, 189.5)})
		
	return entities
