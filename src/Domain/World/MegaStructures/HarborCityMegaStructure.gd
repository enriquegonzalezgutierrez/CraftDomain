# ==============================================================================
# Project: CraftDomain
# Layer: Domain / Infrastructure Bridge (MegaStructures)
# Class: HarborCityMegaStructure
# Description: HANDCRAFTED MULTI-DECK GALLEON & TWO-STORY SEAPORT TAVERN.
#              Rebuilds the Harbor City at global [-150, 0] into a fully playable 
#              cinematic seaport. Features a carved deep-water basin, wooden docks, 
#              a 2-story tavern ("The Salty Sailor Inn") with distinct rooms/stairs, 
#              and a magnificent three-decked Galleon Ship containing a cargo hold, 
#              crew quarters, active stairways, and a private Captain's Cabin.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the multi-chunk 
#   architectural block blueprint and entity allocations.
# - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/HarborCityMegaStructure.gd
# ==============================================================================
class_name HarborCityMegaStructure
extends IMegaStructure

const WATER_LEVEL: int = 9        # Raised water baseline to align with ocean sand shores
const DOCK_LEVEL: int = 11        # Dock walkways sit comfortably above water


func _init() -> void:
	global_center = Vector2i(-150, 0) 
	bounds_size = Vector2i(50, 40)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "STRUCTURE_HARBOR_CITY"


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
			var lx: int = gx - offset.x
			var lz: int = gz - offset.z
			
			# ==================================================================
			# PASS 1: SCULPT AND FORCE PORT COVE BASIN (Y=9 Water level)
			# ==================================================================
			for gy: int in range(0, 32):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < WATER_LEVEL - 3:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy < WATER_LEVEL:
						chunk.set_block(lx, ly, lz, BlockType.Type.SAND) # Seabed sand
					elif gy == WATER_LEVEL:
						# Fill everything in the bounds with Water except solid land borders
						var is_land_border: bool = (gx == min_x or gx == max_x or gz == min_z or gz == max_z)
						if is_land_border:
							chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.WATER)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 2: CONSTRUCT WOODEN DOCKS & WEIGH STATIONS (X: -138 to -125)
			# ==================================================================
			var is_dock_platform: bool = (gx >= -138 and gx <= -125 and gz >= -18 and gz <= 18)
			if is_dock_platform:
				# Supported by thick stone columns extending down to the sea-floor
				for col_y: int in range(6, DOCK_LEVEL):
					set_global_block(chunk, offset, gx, col_y, gz, BlockType.Type.STONE)
				set_global_block(chunk, offset, gx, DOCK_LEVEL, gz, BlockType.Type.WOOD)
				
				# Stacked barrels and chests on the boardwalk walkways
				if gx == -134 and abs(gz) == 12:
					set_global_block(chunk, offset, gx, DOCK_LEVEL + 1, gz, BlockType.Type.WOOD)
					if gz > 0:
						set_global_block(chunk, offset, gx, DOCK_LEVEL + 2, gz, BlockType.Type.WOOD)

			# ==================================================================
			# PASS 3: THE SEAPORT TAVERN ("The Salty Sailor Inn" - X: -138 to -128, Z: -16 to -4)
			# ==================================================================
			var is_tavern_zone: bool = (gx >= -138 and gx <= -128 and gz >= -16 and gz <= -4)
			if is_tavern_zone:
				var tav_dist_x: int = gx - (-133)
				var tav_dist_z: int = gz - (-10)
				var is_tav_wall: bool = (gx == -138 or gx == -128 or gz == -16 or gz == -4)
				var is_tav_door: bool = (gz == -4) and (gx == -133) # Ground floor entrance
				
				for wy: int in range(1, 13): # 12-Block tall Tavern building
					var current_y: int = DOCK_LEVEL + wy
					
					if is_tav_wall:
						if is_tav_door and wy <= 3:
							continue # Leave tall 3-block door archway clear
							
						# Bar window slits on Floor 1 and Floor 2
						var is_window: bool = (wy == 3 or wy == 9) and (abs(tav_dist_x) == 3 or abs(tav_dist_z) == 4)
						if is_window:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					else:
						# ======================================================
						# INTERNAL 3D ROOM DESIGN PIPELINE (SRP Compliant)
						# ======================================================
						if wy <= 5: # First Floor Suites (Empty barracks)
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
						elif wy == 6: # Second Floor wooden separator
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
						elif wy <= 12: # Second Floor Suites
							# Internal divider wall at Z = -10 splits into NW Room & SW Room
							var is_room_divider: bool = (gz == -10)
							var is_corridor_wall: bool = (gx == -131) # central access walkway
							
							if is_room_divider:
								# Door in room divider
								if gx == -135 and wy <= 9:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							elif is_corridor_wall:
								# Doors to rooms
								var is_room_door: bool = (gz == -7 or gz == -13) and wy <= 9
								if is_room_door:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								# NW Bedchamber Cozy bed
								var is_bed_wood: bool = (gx == -136 or gx == -135) and (gz == -14 or gz == -13) and wy == 7
								var is_bed_pillow: bool = (gx == -136 or gx == -135) and (gz == -15) and wy == 8
								
								if is_bed_wood:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_bed_pillow:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.CLOUD)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

				# Flat Wooden Planks Roof for the tavern
				set_global_block(chunk, offset, gx, DOCK_LEVEL + 13, gz, BlockType.Type.OAK_PLANKS)

			# ==================================================================
			# PASS 4: THE GALLEON SHIP (Length 24, Width 11 - X: -168 to -144, Z: -5 to 5)
			# ==================================================================
			var is_ship_zone: bool = (gx >= -168 and gx <= -144 and gz >= -5 and gz <= 5)
			if is_ship_zone:
				var ship_x: int = gx - (-156) # Center X of ship on -156
				var ship_z: int = gz - 0
				
				# Hull curve formulas
				var bow_taper: float = float(abs(ship_z)) / 5.0
				var hull_limit: float = 12.0 - (bow_taper * 4.0)
				
				if float(abs(ship_x)) <= hull_limit:
					# Ensure the local water is cleared inside the hull volume to avoid floods!
					for water_clear_y: int in range(WATER_LEVEL, WATER_LEVEL + 4):
						set_global_block(chunk, offset, gx, water_clear_y, gz, BlockType.Type.AIR)
						
					# --- LOWER CUBIERTA BODEGA (Cargo hold under water level Y: 6 to 10) ---
					for gy: int in range(6, DOCK_LEVEL):
						var is_bottom_hull: bool = (gy == 6)
						var is_side_hull: bool = (float(abs(ship_x)) > hull_limit - 1.0) or abs(ship_z) == 5
						
						if is_bottom_hull:
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD) # Solid hull base
						elif is_side_hull:
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD) # Wood ribs
						else:
							# Crew hammock beds at the front cargo
							var is_bunk: bool = (ship_x <= -5 and ship_x >= -8) and (ship_z == -3 or ship_z == 3) and (gy == 7)
							if is_bunk:
								set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.CLOUD)
							else:
								set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR) # Walkable cargo hold!
								
					# --- MAIN CUBIERTA PLATFORM (Y = 11 / DOCK_LEVEL) ---
					# Slabs and openings for cargo hold ladder (X = -153, Z = 0)
					var is_hatch: bool = (ship_x == -3 and ship_z == 0)
					if not is_hatch:
						set_global_block(chunk, offset, gx, DOCK_LEVEL, gz, BlockType.Type.OAK_PLANKS)
					else:
						# Hold ladder step-posts (Y=7 to Y=11)
						for ly: int in range(7, DOCK_LEVEL + 1):
							set_global_block(chunk, offset, gx, ly, gz + 1, BlockType.Type.WOOD)
							
					# --- UPPER QUARTERDECK & CAPTAIN'S CABIN (Aft of ship / X >= 6 / Y: 12 to 21) ---
					var is_aft_cabin: bool = (ship_x >= 5 and ship_x <= 11 and abs(ship_z) <= 3)
					if is_aft_cabin:
						var is_cabin_wall: bool = (ship_x == 5 or ship_x == 11 or abs(ship_z) == 3)
						for wy: int in range(1, 6): # Cabin height: 5 blocks
							var current_y: int = DOCK_LEVEL + wy
							if is_cabin_wall:
								# Elegant glass bay windows looking out to popa
								var is_cabin_window: bool = (ship_x == 11 and wy == 2)
								if is_cabin_window:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
							else:
								# Inside Captain's Cabin!
								# Elegant canopy bed (X=166..167, Z=same)
								var is_captain_bed: bool = (ship_x >= 10 and ship_x <= 11) and (ship_z == -2) and wy == 1
								var is_captain_pillow: bool = (ship_x == 11) and (ship_z == -2) and wy == 2
								
								if is_captain_bed:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_captain_pillow:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.CLOUD)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR) # Spacious cabin space
									
						# Cabin wood planks roof ceiling
						set_global_block(chunk, offset, gx, DOCK_LEVEL + 5, gz, BlockType.Type.OAK_PLANKS)
						
					else:
						# Side wood deck railings for main deck (Y=12)
						var is_deck_railing: bool = (float(abs(ship_x)) > hull_limit - 1.0) or abs(ship_z) == 5
						if is_deck_railing:
							set_global_block(chunk, offset, gx, DOCK_LEVEL + 1, gz, BlockType.Type.WOOD)
							
					# --- BILLOWING WIND-SWAY MASTS & CLOUD SAILS (Rising up to Y = 28) ---
					var is_mast: bool = (ship_z == 0) and (ship_x == -7 or ship_x == 1 or ship_x == 8)
					if is_mast:
						# Draw solid central vertical wood post
						for gy: int in range(DOCK_LEVEL + 1, DOCK_LEVEL + 17):
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
							
						# Billowing cloud-wool sails (Y: 15 to 22)
						for gy: int in range(DOCK_LEVEL + 4, DOCK_LEVEL + 13):
							var sail_radius: int = 13 - gy
							if sail_radius > 4: sail_radius = 4
							for sz: int in range(-sail_radius, sail_radius + 1):
								if sz != 0: # Leave central mast hollow
									set_global_block(chunk, offset, gx - 1, gy, gz + sz, BlockType.Type.CLOUD)


## Concrete Contract: Dispatches inhabitants and interactive props strictly inside their chunk grids
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Seaport Center is -150, 0. This falls into chunk (-10, 0, 0).
	# Coordinate conversions:
	# Chunk (-10, 0) -> X [-160, -145], Z [-16, 15]
	# Chunk (-9, 0) -> X [-144, -129], Z [-16, 15]
	
	# ==========================================================================
	# 1. EAST SEAPORT CHUNK (-9, 0, 0) - COZY TAVERN & MERCHANTS DOCK
	# ==========================================================================
	if chunk_pos.x == -9 and chunk_pos.z == 0:
		# Dock Clerk (Villager NPC) inspecting the stacked wooden crates
		entities.append({"mob_id": 100, "pos": Vector3(-138.5, 12.0, 3.5)})
		
		# Tavern Barkeep Merchant inside the cozy Market Cabin (X: -10.5, Z: -3.5)
		entities.append({"mob_id": 101, "pos": Vector3(-136.5, 12.0, -3.5)})
		
		# Royal Guard watching the harbor docks
		entities.append({"mob_id": 102, "pos": Vector3(-131.5, 12.5, -4.5)})
		
	# ==========================================================================
	# 2. WEST NAVAL CHUNK (-10, 0, 0) - CUBIERTAS DE COMBATE DEL GALEÓN
	# ==========================================================================
	elif chunk_pos.x == -10 and chunk_pos.z == 0:
		# Port Master Ship Captain (Guard) standing at the helm on Quarterdeck (Y = 16)
		entities.append({"mob_id": 102, "pos": Vector3(-150.5, 17.5, 0.5)})
		
		# High-Security Captain's Cabin Loot Chest (Inside Cabin at Popa, Y = 16)
		entities.append({"mob_id": 200, "pos": Vector3(-146.5, 17.5, -2.5)})
		
		# Crew Sailor (Villager) sleeping in the bunk bed on lower cargo deck (Y = 7)
		entities.append({"mob_id": 100, "pos": Vector3(-162.5, 7.5, -3.5)})
		
	return entities
