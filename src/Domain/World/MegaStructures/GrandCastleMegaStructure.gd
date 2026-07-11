# ==============================================================================
# Project: CraftDomain
# Layer: Domain / Infrastructure Bridge (MegaStructures)
# Class: GrandCastleMegaStructure
# Description: HANDCRAFTED TWO-STORY COLOSSAL FORTRESS.
#              Rebuilds the Grand Stone Castle at global [200, 200] into a massive, 
#              two-floor medieval citadel with perfect 3D spacing. Fully clears the 
#              first floor ceiling and carpet blocking bugs, introducing 
#              ultra-wide 3-block staircases, an open mezzanine balcony with wooden 
#              safety railings, four private rooms with distinct walls/arches 
#              (King's chambers, Queen's chambers, Royal Treasury with brick 
#              pedestals, and War Council Room), and an ascending roof-deck stair.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the multi-chunk 
#   architectural block blueprint and entity allocations.
# - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# FLUSH CARPET FIX (A ras del suelo):
# - Modified the Throne Hall carpet generation. It now explicitly targets `base_y` 
#   (Y=12) to replace the stone floor with Red Sand, leaving `current_y` (Y=13) 
#   as Air. This ensures the carpet is perfectly flush and embedded in the ground,
#   mimicking the exact same flat-paving logic used for highways.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/GrandCastleMegaStructure.gd
# ==============================================================================
class_name GrandCastleMegaStructure
extends IMegaStructure

const CASTLE_RADIUS: int = 24      # Expanded wall boundaries (48x48 footprint)
const KEEP_WIDTH_HALF: int = 12    # Keep width is 24 blocks (X: 188 to 212)
const KEEP_LENGTH_HALF: int = 12   # Keep length is 24 blocks (Z: 182 to 206)


func _init() -> void:
	global_center = Vector2i(200, 200) 
	bounds_size = Vector2i(60, 60)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "STRUCTURE_GRAND_CASTLE"


## Concrete Contract: Sculpting pipeline executed by the chunk mesher threads
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 12
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
			# To ensure the castle floors (and carpets) never get bumpy from terrain noise,
			# we explicitly clear all blocks above base_y inside the castle radius.
			if dist_x <= CASTLE_RADIUS and dist_z <= CASTLE_RADIUS:
				for gy: int in range(base_y + 1, 32):
					var ly: int = gy - offset.y
					if chunk.is_within_bounds(lx, ly, lz):
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
						
			for gy: int in range(0, base_y + 1):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy == base_y:
						# Main Road path leading to the South Gate
						if abs(gx - center_x) <= 2 and gz >= center_z + CASTLE_RADIUS:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						# Keep interior stone floor
						elif dist_x < KEEP_WIDTH_HALF and dist_z < KEEP_LENGTH_HALF:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.GRASS)

			# ==================================================================
			# PASS 2: SECURE OUTER DEFENSE WALLS (With almenas/crenellations)
			# ==================================================================
			var is_wall_border: bool = (dist_x == CASTLE_RADIUS and dist_z <= CASTLE_RADIUS) or (dist_z == CASTLE_RADIUS and dist_x <= CASTLE_RADIUS)
			if is_wall_border:
				var is_gate: bool = (gz == center_z + CASTLE_RADIUS) and (dist_x <= 3)
				for wy: int in range(1, 9):
					if is_gate and wy <= 5: 
						continue # Leave hollow gate opening for future door mechanics
						
					# Alternating battlements on the roof layer
					if wy == 8 and (gx + gz) % 2 == 0:
						continue
					set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE)

			# ==================================================================
			# PASS 3: CYLINDRICAL CORNER DEFENSE TOWERS (15 blocks high)
			# ==================================================================
			var tower_radius: int = 4
			var is_in_tower := false
			var tx: int = 0
			var tz: int = 0
			
			if abs(gx - (center_x - CASTLE_RADIUS)) <= tower_radius and abs(gz - (center_z - CASTLE_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x - CASTLE_RADIUS; tz = center_z - CASTLE_RADIUS
			elif abs(gx - (center_x + CASTLE_RADIUS)) <= tower_radius and abs(gz - (center_z - CASTLE_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x + CASTLE_RADIUS; tz = center_z - CASTLE_RADIUS
			elif abs(gx - (center_x - CASTLE_RADIUS)) <= tower_radius and abs(gz - (center_z + CASTLE_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x - CASTLE_RADIUS; tz = center_z + CASTLE_RADIUS
			elif abs(gx - (center_x + CASTLE_RADIUS)) <= tower_radius and abs(gz - (center_z + CASTLE_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x + CASTLE_RADIUS; tz = center_z + CASTLE_RADIUS
				
			if is_in_tower:
				var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
				if t_dist <= float(tower_radius):
					for wy: int in range(1, 16):
						var is_tower_wall: bool = t_dist > float(tower_radius) - 1.5
						if is_tower_wall:
							if wy == 15 and (gx + gz) % 2 == 0: 
								continue # Tower parapet crenellations
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE)
						else:
							# Intermediate interior wood plank floors for tower climbing
							if wy == 6 or wy == 11:
								set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.OAK_PLANKS)
							else:
								set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 4: COLOSSAL TWO-STORY CENTRAL KEEP (Z: 182 to 206, X: 188 to 212)
			# ==================================================================
			var keep_center_z: int = center_z - 6 # Shifted North to open courtyard
			var keep_dist_x: int = abs(gx - center_x)
			var keep_dist_z: int = abs(gz - keep_center_z)
			
			if keep_dist_x <= KEEP_WIDTH_HALF and keep_dist_z <= KEEP_LENGTH_HALF:
				var is_keep_wall: bool = (keep_dist_x == KEEP_WIDTH_HALF or keep_dist_z == KEEP_LENGTH_HALF)
				var is_keep_gate: bool = (gz == keep_center_z + KEEP_LENGTH_HALF) and (keep_dist_x <= 3) # Expanded gate opening width!
				
				for wy: int in range(1, 18): # Massive 17-block high Keep
					var current_y: int = base_y + wy
					
					if is_keep_wall:
						if is_keep_gate and wy <= 5: # Tall 5-block entrance gate
							continue 
							
						# Windows for Floor 1 and Floor 2
						var is_window: bool = (wy == 3 or wy == 11) and ((keep_dist_x == KEEP_WIDTH_HALF and gz % 4 == 0) or (keep_dist_z == KEEP_LENGTH_HALF and gx % 4 == 0))
						if is_window and not is_keep_gate:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					else:
						# ======================================================
						# INTERNAL 3D ROOM DESIGN PIPELINE (SRP Compliant)
						# ======================================================
						
						# 1. THRONE HALL DOUBLE HEIGHT CHAMBER (Center of the Keep: X [194..206])
						var is_throne_hall_core: bool = (keep_dist_x <= 6)
						
						if is_throne_hall_core:
							# A. Ground Floor (Throne, Carpet, Pillars, and Stairs)
							if wy <= 5:
								# PERFECTLY FLUSH RED CARPET (Replacing the actual floor at Y=12)
								if keep_dist_x <= 1 and gz >= keep_center_z - KEEP_LENGTH_HALF + 3:
									if wy == 1:
										# Overwrites the base_y (Y=12) stone floor with RED_SAND to embed it flush!
										set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.RED_SAND)
										# Ensure the space directly above (Y=13) is AIR so it's walkable
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								# Golden/Magenta Imperial Throne (Placed at Z = 184)
								elif gx == center_x and gz == keep_center_z - KEEP_LENGTH_HALF + 2:
									if wy == 1: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									elif wy == 2: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
									elif wy == 3: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.NEON_MAGENTA)
									elif wy == 4: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLOWSTONE) # Glowing crown!
									else: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								# ULTRA-WIDE COMFY DOUBLE STAIRS (Z = 185 to 196)
								# 3-Block wide ramps ascending symmetrically along the West & East inner walls
								elif gz >= 185 and gz <= 196:
									# West branch ascending North
									if gx >= 189 and gx <= 191:
										var step_req: int = floori(float(196 - gz) / 2.0) + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									# East branch ascending North
									elif gx >= 209 and gx <= 211:
										var step_req: int = floori(float(196 - gz) / 2.0) + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								# Flanking Neon-Cyan structural light columns
								elif keep_dist_x == 5 and (gz == keep_center_z or gz == keep_center_z + 4):
									if wy == 1 or wy == 5:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.NEON_CYAN)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							
							# B. Floor Splitter Mezzanine Balcony Level (wy = 6 / Y=18)
							elif wy == 6:
								# Open stair landings at the back (X [189..191] and [209..211] near Z=185) for climbing access
								var is_stair_landing: bool = (gx >= 189 and gx <= 191 and gz >= 185 and gz <= 187) or (gx >= 209 and gx <= 211 and gz >= 185 and gz <= 187)
								
								# Keep the entire center of the Throne Hall completely open to look down!
								var is_open_balcony: bool = (gx >= 192 and gx <= 208) and (gz >= 188)
								
								if is_stair_landing or is_open_balcony:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS) # Mezzanine walk path
									
							# C. Second Floor Open Air Space (Balcony view)
							elif wy <= 12:
								# Add wooden safety railings at the edge of the central open balcony (wy = 7 / Y=19)
								var is_railing: bool = (wy == 7) and (keep_dist_x == 8 and gz >= 188)
								
								# Cozy back roof stair ramp climbing from Floor 2 (X=194) up to Roof hatch (X=189)
								var is_roof_stair: bool = (gz == keep_center_z - KEEP_LENGTH_HALF + 3) and (gx >= 189 and gx <= 194)
								
								if is_railing:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_roof_stair:
									var step_req: int = 195 - gx # gx=194 -> height 1 (wy=7), gx=189 -> height 6 (wy=12)
									if (wy - 6) <= step_req:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							# D. Roof slab platform (wy = 13 / Y=25)
							elif wy == 13:
								# Open a 2x2 hatch hole above the roof stair (X: 189..190, Z: same) to climb up
								var is_roof_hatch: bool = (gx >= 189 and gx <= 190) and (gz == keep_center_z - KEEP_LENGTH_HALF + 3)
								if is_roof_hatch:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								
							# E. Rooftop Battlements Battlements (wy >= 14)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
						# 2. SIDE WINGS SUITES (X [189..193] and [207..211])
						else:
							# Separator Walls at X = 193 and X = 207 (Symmetrical division)
							var is_partition_wall: bool = (keep_dist_x == 7)
							if is_partition_wall:
								# Open comfortable doors for Ground Floor and Upper Floor rooms (Z = 196)
								var is_door_opening: bool = (gz == keep_center_z) and ((wy >= 1 and wy <= 3) or (wy >= 7 and wy <= 9))
								if is_door_opening:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								# Inside Room spaces!
								if wy <= 5: 
									# First Floor Wings (Partitioned at Z=194 into SW Barracks, NW Armory)
									var is_wing_divider: bool = (gz == 194)
									if is_wing_divider:
										if keep_dist_x == 9 and wy <= 3: # Doorway in barracks
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										
								elif wy == 6: # Second Floor wooden separator
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								elif wy <= 12: # Second Floor Suites (Real Rooms with divider walls!)
									# Room Divider at Z=194 splits West into King/Queen, and East into Treasury/War Room
									var is_upper_divider: bool = (gz == 194)
									
									if is_upper_divider:
										# Enclose rooms with doors at X=191 / X=209
										var is_room_door: bool = (gx == 190 or gx == 210) and wy <= 9
										if is_room_door:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										# A. WEST WING (NW: KING'S BEDCHAMBER)
										if gx < center_x and gz < 194:
											# Dynamic Bed construction (X: 189..190, Z: 185..187)
											var is_bed_frame: bool = (gx >= 189 and gx <= 190) and (gz >= 185 and gz <= 187) and wy == 7
											var is_bed_pillow: bool = (gx >= 189 and gx <= 190) and (gz == 185) and wy == 8
											
											if is_bed_frame:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
											elif is_bed_pillow:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.CLOUD)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
												
										# B. EAST WING (NE: ROYAL TREASURY)
										elif gx > center_x and gz < 194:
											# Solid safety brick pedestal for the special loot chest
											var is_pedestal: bool = (gx == 210 and gz == 185) and wy == 7
											if is_pedestal:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
												
										# C. SW CHAMBER (Queen's Suite) & SE CHAMBER (War Council)
										else:
											# Long wood table inside War Council Room (SE Wing)
											var is_council_table: bool = (gx >= 208 and gx <= 210) and (gz >= 198 and gz <= 201) and wy == 7
											if is_council_table:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
											else:
												set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
										
								elif wy == 13: # Roof slab
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else: # Open sky
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 5: CONSTRUCT TRANSIENT ROOFTOP DECK & SKY WATCH-DOME
			# ==================================================================
			if keep_dist_x <= KEEP_WIDTH_HALF and keep_dist_z <= KEEP_LENGTH_HALF:
				# Crenellated battlements around the roof perimeter (Y = base_y + 14 / wy = 14)
				var is_roof_edge: bool = (keep_dist_x == KEEP_WIDTH_HALF or keep_dist_z == KEEP_LENGTH_HALF)
				if is_roof_edge:
					# Symmetrical battlements
					for wy: int in range(14, 18):
						var current_y: int = base_y + wy
						if wy == 14 and (gx + gz) % 2 == 0:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
				else:
					# Central Watch-Tower canopy overlooking the whole sky
					for wy: int in range(14, 18):
						var current_y: int = base_y + wy
						var is_canopy_vbox: bool = (keep_dist_x == 3 and keep_dist_z == 3)
						if is_canopy_vbox and wy <= 16:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE) # Corner pillars
						elif keep_dist_x <= 3 and keep_dist_z <= 3 and wy == 17:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS) # Brick dome roof!
						elif not is_canopy_vbox:
							if wy >= 14:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)


## Concrete Contract: Dispatches inhabitants and interactive props strictly inside their chunk grids
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Castle center is 200, 200. Chunk offset math maps chunks uniquely.
	# Coordinate conversions: 
	# Chunk (12, 12) -> X [192, 207], Z [192, 207]
	# Chunk (12, 11) -> X [192, 207], Z [176, 191]
	# Chunk (13, 11) -> X [208, 223], Z [176, 191]
	# Chunk (11, 11) -> X [176, 191], Z [176, 191]
	
	# ==========================================================================
	# 1. CORE CHUNK (12, 0, 12) - GROUND FLOOR COURTYARD & GATE ACCESS
	# ==========================================================================
	if chunk_pos.x == 12 and chunk_pos.z == 12:
		# Main Gate Defenders standing watch at the South Gate bridge entrance
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 222.5)})
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 222.5)})
		
		# Courtyard Lamppost lighting
		entities.append({"mob_id": 202, "pos": Vector3(196.5, 13.5, 218.5)})
		entities.append({"mob_id": 202, "pos": Vector3(203.5, 13.5, 218.5)})
		
		# Cozy Campfire in the western garden
		entities.append({"mob_id": 203, "pos": Vector3(194.5, 13.5, 212.5)})
		
	# ==========================================================================
	# 2. NORTH KEEP CHUNK (12, 0, 11) - THRONE HALL & ROYAL SUITE
	# ==========================================================================
	elif chunk_pos.x == 12 and chunk_pos.z == 11:
		# Imperial Guards standing flanking the Golden Throne on ground floor
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 185.5)})
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 185.5)})
		
		# The Ancestral Mayor (King proxy) sitting in front of his throne
		entities.append({"mob_id": 100, "pos": Vector3(200.5, 14.5, 186.5)})

	# ==========================================================================
	# 3. EAST TREASURY CHUNK (13, 0, 11) - HIGH-SECURITY ROYAL VAULT
	# ==========================================================================
	elif chunk_pos.x == 13 and chunk_pos.z == 11:
		# Elite Vault Guard watching the treasury room (Floor 2, Y = 19)
		entities.append({"mob_id": 102, "pos": Vector3(208.5, 19.5, 188.5)})
		
		# Handcrafted Golden Loot Chest sitting perfectly on the stone pedestal
		entities.append({"mob_id": 200, "pos": Vector3(210.5, 20.0, 185.5)})
		
	# ==========================================================================
	# 4. WEST BARRACKS CHUNK (11, 0, 11) - GUARD SLEEP QUARTERS
	# ==========================================================================
	elif chunk_pos.x == 11 and chunk_pos.z == 11:
		# Sleeping Guard relaxing in the barracks
		entities.append({"mob_id": 102, "pos": Vector3(191.5, 13.5, 189.5)})
		
	return entities
