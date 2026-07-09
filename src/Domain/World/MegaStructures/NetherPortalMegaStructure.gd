# ==============================================================================
# Project: CraftDomain
# Layer: Domain / Infrastructure Bridge (MegaStructures)
# Class: NetherPortalMegaStructure
# Description: HANDCRAFTED TWO-STORY DEMONIC CITADEL & LAVA FORTRESS.
#              Rebuilds the Nether Outpost at global [-300, -300] into a fully playable 
#              multi-floor medieval fortress. Features concentric flowing lava moats, 
#              solid stone bridges, corner defense towers rising to Y=23, a double-height 
#              gothic Portal Sanctuary Cathedral, and an elevated tattered treasury room 
#              storing the high-value Nether Loot Chest.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the multi-chunk 
#   architectural block blueprint and entity allocations.
# - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/NetherPortalMegaStructure.gd
# ==============================================================================
class_name NetherPortalMegaStructure
extends IMegaStructure

const OUTPOST_RADIUS: int = 18     # 36x36 total wall boundaries footprint
const SANCTUARY_HALF_SIZE: int = 8 # 16x16 central portal cathedral hall


func _init() -> void:
	global_center = Vector2i(-300, -300) 
	bounds_size = Vector2i(50, 50)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "BIOME_NETHER_OUTPOST"


## Concrete Contract: Sculpting pipeline executed by the chunk mesher threads
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 8
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
			# PASS 1: SCULPT BURNT GROUND & VOLATILE CONCENTRIC LAVA MOATS
			# ==================================================================
			for gy: int in range(0, 32):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y - 2:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.RED_SAND) # Netherrack ground
					elif gy == base_y:
						# Concentric Moat: Lava rings at distance 15 & 16 surrounding the castle
						var is_lava_moat: bool = (dist_x == 15 or dist_x == 16 or dist_z == 15 or dist_z == 16) and (dist_x <= 16 and dist_z <= 16)
						# Keep bridges at X = 0 (North/South entrance bridge)
						var is_bridge: bool = (abs(gx - center_x) <= 2) and (dist_z >= 14 and dist_z <= 17)
						
						if is_lava_moat and not is_bridge:
							chunk.set_block(lx, ly, lz, BlockType.Type.LAVA)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.RED_SAND)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 2: SECURE OUTER DEFENSE RAMPARTS (With crenellated adarves)
			# ==================================================================
			var is_wall_border: bool = (dist_x == OUTPOST_RADIUS and dist_z <= OUTPOST_RADIUS) or (dist_z == OUTPOST_RADIUS and dist_x <= OUTPOST_RADIUS)
			if is_wall_border:
				# South bridge gate opening at Z = center_z + OUTPOST_RADIUS
				var is_gate: bool = (gz == center_z + OUTPOST_RADIUS) and (dist_x <= 2)
				
				for wy: int in range(1, 8): # 7 blocks tall rampart walls
					var current_y: int = base_y + wy
					if is_gate and wy <= 4:
						continue # gate opening
						
					# Wall walkway on Y = 14 (wy = 6) is flat Stone for patrol
					if wy == 6:
						set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					elif wy == 7:
						# Crenellated battlements along the rampart walkways
						if (gx + gz) % 2 == 0:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
					else:
						set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)

			# ==================================================================
			# PASS 3: CYLINDRICAL CORNER OBSIDIAN TOWERS (Rising to Y = 23)
			# ==================================================================
			var tower_radius: int = 4
			var is_in_tower := false
			var tx: int = 0
			var tz: int = 0
			
			if abs(gx - (center_x - OUTPOST_RADIUS)) <= tower_radius and abs(gz - (center_z - OUTPOST_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x - OUTPOST_RADIUS; tz = center_z - OUTPOST_RADIUS
			elif abs(gx - (center_x + OUTPOST_RADIUS)) <= tower_radius and abs(gz - (center_z - OUTPOST_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x + OUTPOST_RADIUS; tz = center_z - OUTPOST_RADIUS
			elif abs(gx - (center_x - OUTPOST_RADIUS)) <= tower_radius and abs(gz - (center_z + OUTPOST_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x - OUTPOST_RADIUS; tz = center_z + OUTPOST_RADIUS
			elif abs(gx - (center_x + OUTPOST_RADIUS)) <= tower_radius and abs(gz - (center_z + OUTPOST_RADIUS)) <= tower_radius:
				is_in_tower = true; tx = center_x + OUTPOST_RADIUS; tz = center_z + OUTPOST_RADIUS
				
			if is_in_tower:
				var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
				if t_dist <= float(tower_radius):
					for wy: int in range(1, 16):
						var current_y: int = base_y + wy
						var is_tower_wall: bool = t_dist > float(tower_radius) - 1.5
						if is_tower_wall:
							if wy == 15 and (gx + gz) % 2 == 0: 
								continue # Tower battlements
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE) # Obsidian casing
						else:
							# Intermediate interior levels climbing
							if wy == 6 or wy == 11:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 4: CENTRAL SANCTUARY CATHEDRAL (Obsidian Spire: Z/X: -308 to -292)
			# ==================================================================
			var is_sanctuary: bool = (dist_x <= SANCTUARY_HALF_SIZE and dist_z <= SANCTUARY_HALF_SIZE)
			if is_sanctuary:
				var is_sanc_wall: bool = (dist_x == SANCTUARY_HALF_SIZE or dist_z == SANCTUARY_HALF_SIZE)
				var is_sanc_gate: bool = (gz == center_z + SANCTUARY_HALF_SIZE) and (dist_x <= 3) # Wide 6-block South gate
				
				for wy: int in range(1, 16): # 15-Block tall gothic cathedral
					var current_y: int = base_y + wy
					
					if is_sanc_wall:
						if is_sanc_gate and wy <= 5: # High entry archway
							continue
							
						# Gothic slit glass windows
						var is_window: bool = (wy == 3 or wy == 10) and ((dist_x == SANCTUARY_HALF_SIZE and gz % 4 == 0) or (dist_z == SANCTUARY_HALF_SIZE and gx % 4 == 0))
						if is_window and not is_sanc_gate:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					else:
						# ======================================================
						# SANCTUARY INTERIOR 3D SCHEMES
						# ======================================================
						var is_portal_core: bool = (dist_x <= 4 and dist_z <= 2)
						
						if is_portal_core:
							# A. Ancient Nether Portal Frame (Height 9, Width 9 - centered at Z = -300)
							if gz == center_z and abs(gx - center_x) <= 4:
								var py: int = wy
								if py <= 8:
									var is_outer_frame: bool = (abs(gx - center_x) == 4) or (py == 1) or (py == 8)
									if is_outer_frame:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE) # Obsidian Frame
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.NEON_MAGENTA) # Portal curtain
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
						# B. Symmetrical Wide Stone Stairs (climbing along the back West & East walls)
						elif gz == center_z - 6:
							# West staircase ascending South
							if gx >= center_x - 7 and gx <= center_x - 5:
								var step_req: int = gx - (center_x - 7) + 1
								if wy <= step_req:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							# East staircase ascending South
							elif gx >= center_x + 5 and gx <= center_x + 7:
								var step_req: int = (center_x + 7) - gx + 1
								if wy <= step_req:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
						# C. Ceiling Floor Division (Y = 14 / wy = 6)
						elif wy == 6:
							# Open landings at the back corners (Z = -306)
							var is_stair_landing: bool = (gz == center_z - 6) and (abs(gx - center_x) >= 5 and abs(gx - center_x) <= 7)
							var is_portal_open_view: bool = (gz >= center_z - 3) # Central open ceiling to admire portal
							
							if is_stair_landing or is_portal_open_view:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								
						# D. Upper Level suites (Y: 15 to 19 / wy: 7 to 11)
						elif wy <= 11:
							# Enclosed treasury room wall at Z = -303 (wy = 7 to 11)
							var is_treasury_wall: bool = (gz == center_z - 3)
							if is_treasury_wall:
								# Arch door opening at center
								if abs(gx - center_x) <= 1 and wy <= 9:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								# NW Suite: High-security Treasury (Left hollow for entities spawning)
								if gx < center_x and gz < center_z - 3:
									# Support pedestal for Loot Chest
									var is_pedestal: bool = (gx == center_x - 6 and gz == center_z - 6) and (wy == 7)
									if is_pedestal:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
						# E. Solid Roof Platform (wy = 12 / Y = 20)
						elif wy == 12:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							
						# F. Rooftop battlements crenellations (wy >= 13)
						else:
							var is_sanc_roof_edge: bool = (dist_x == SANCTUARY_HALF_SIZE - 1 or dist_z == SANCTUARY_HALF_SIZE - 1)
							if is_sanc_roof_edge:
								if wy == 13 and (gx + gz) % 2 == 0:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)


## Concrete Contract: Dispatches inhabitants and interactive props strictly inside their chunk grids
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Central coordinates of Nether Portal: [-300, -300].
	# Fits precisely inside Chunk (-19, 0, -19) for X [-304..-289] and Z [-304..-289]
	if chunk_pos.x == -19 and chunk_pos.z == -19:
		# 1. NETHER VAULT CHEST (Sitting elegantly on Floor 2 brick pedestal)
		# Pedestal is at X = -306 (center_x - 6), Z = -306, Y = base_y + 7 = 15.
		# We spawn the chest at Y = 16.0 to rest perfectly on the bricks!
		entities.append({"mob_id": 200, "pos": Vector3(-306.5, 16.0, -306.5)})
		
		# 2. NETHER GUARDIAN KNIGHTS (Zombies patrolling bridge entrances and main hall)
		entities.append({"mob_id": 10, "pos": Vector3(-295.5, 9.5, -298.5)}) # Portal right flank
		entities.append({"mob_id": 10, "pos": Vector3(-304.5, 9.5, -298.5)}) # Portal left flank
		
	return entities
