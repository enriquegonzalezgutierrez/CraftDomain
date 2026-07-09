# ==============================================================================
# Project: CraftDomain
# Layer: Domain / Infrastructure Bridge (MegaStructures)
# Class: DesertOasisMegaStructure
# Description: HANDCRAFTED TWO-STORY STEP-PYRAMID & OASIS SANCTUARY.
#              Rebuilds the Desert Pyramid at global [-150, 250] into a fully playable 
#              multi-floor dungeon. Features a stepped outer casing, a central 
#              Sarcophagus chamber with side channels, wide rising stone stairs, 
#              a spacious Mezzanine Balcony, an enclosed High-Security Pharaoh's 
#              Treasury on Floor 2, and an active rooftop beacon lamp.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the multi-chunk 
#   architectural block blueprint and entity allocations.
# - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/DesertOasisMegaStructure.gd
# ==============================================================================
class_name DesertOasisMegaStructure
extends IMegaStructure

const PYRAMID_BASE_RADIUS: int = 12 # 24x24 block base
const PYRAMID_HEIGHT: int = 10      # 10-Tiers high stepped pyramid


func _init() -> void:
	global_center = Vector2i(-150, 250) 
	bounds_size = Vector2i(40, 40)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "STRUCTURE_DESERT_OASIS"


## Concrete Contract: Sculpting pipeline executed by the chunk mesher threads
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 15
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
			# PASS 1: FLATTEN SANDY OASIS WATER ESTANQUE
			# ==================================================================
			for gy: int in range(0, 32):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y - 3:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.SAND) # Sandy lecho
					elif gy == base_y:
						# Cross-shaped oasis pool around the pyramid structure
						var is_pool: bool = (dist_x <= 16 and dist_z <= 3) or (dist_z <= 16 and dist_x <= 3)
						var is_pyramid_footprint: bool = (dist_x <= PYRAMID_BASE_RADIUS and dist_z <= PYRAMID_BASE_RADIUS)
						
						if is_pool and not is_pyramid_footprint:
							chunk.set_block(lx, ly, lz, BlockType.Type.WATER)
						elif is_pyramid_footprint:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE) # Hard basalt base
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 2: STEPPED SOLID PYRAMID CASING (10 stepped levels Y=16 to Y=25)
			# ==================================================================
			for step_y: int in range(1, PYRAMID_HEIGHT + 1):
				var current_y: int = base_y + step_y
				var current_radius: int = PYRAMID_BASE_RADIUS - step_y + 1
				
				if dist_x <= current_radius and dist_z <= current_radius:
					var is_outer_casing: bool = (dist_x == current_radius or dist_z == current_radius)
					var is_entrance_gate: bool = (gz == center_z + current_radius) and (dist_x <= 2) and (step_y <= 4)
					
					if is_outer_casing:
						if is_entrance_gate:
							continue # Keep majestic archway entry clear
							
						# Pattern casing using Red Sand and Oak Planks (mural reliefs)
						if (gx + gz) % 2 == 0:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.RED_SAND)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
					else:
						# ======================================================
						# INTERNAL CHAMBERS MATHEMATICAL SPACING
						# ======================================================
						var wy: int = step_y # relative height (1 to 10)
						
						# 1. CENTRAL SACRED ALTAR HAL (Double height center / X [194..206] -> shifted: dist_x <= 5)
						var is_inner_sanctuary: bool = (dist_x <= 5 and dist_z <= 5)
						
						if is_inner_sanctuary:
							if wy <= 4: # Floor 1 Hollow hall (Y: 16 to 19)
								# A. Pharaoh Sarcophagus Pedestal (Center of the room X=0, Z=0)
								var is_sarcophagus: bool = (dist_x <= 1 and dist_z <= 1)
								
								if is_sarcophagus:
									if wy == 1: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									elif wy == 2: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
									elif wy == 3: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLOWSTONE) # Glowing relic!
									else: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								# B. Winding Stairs rising to Floor 2 (Z = 246, X: West/East)
								elif gz == center_z - 4:
									# West ramp ascending Left
									if gx >= center_x - 5 and gx <= center_x - 2:
										var step_req: int = gx - (center_x - 5) + 1 # West starts height 1, climbs to 4
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									# East ramp ascending Right
									elif gx >= center_x + 2 and gx <= center_x + 5:
										var step_req: int = (center_x + 5) - gx + 1 # East starts height 1, climbs to 4
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							elif wy == 5: # Ceiling division level (Y = 20)
								# Open comfortable landings above stairs
								var is_stair_landing: bool = (gz == center_z - 4) and (abs(gx - center_x) >= 2 and abs(gx - center_x) <= 5)
								var is_open_well: bool = (dist_x <= 3 and dist_z <= 3) # Central view well to sarcophagus
								
								if is_stair_landing or is_open_well:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
									
							elif wy <= 8: # Floor 2 Mezzanine Corridor (Y: 21 to 23)
								# Safety barriers (fence) around the central viewing well (wy = 6)
								var is_fence: bool = (wy == 6) and (dist_x == 4 or dist_z == 4)
								
								# Ascent stair climbing from Floor 2 up to the Rooftop Beacon
								var is_roof_stair: bool = (gz == center_z + 4) and (gx >= center_x - 3 and gx <= center_x + 2)
								
								if is_fence:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_roof_stair:
									var step_req: int = gx - (center_x - 3) + 1 # climbs West-East up to hatch
									if (wy - 5) <= step_req:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							elif wy == 9: # Rooftop Slab (Y = 24)
								# Open hatch above the roof stair
								var is_hatch_hole: bool = (gz == center_z + 4) and (gx >= center_x + 1 and gx <= center_x + 2)
								if is_hatch_hole:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

						# 2. INNER SIDE SUITES (Outer ring of the interior spaces)
						else:
							# Divider walls at distance 6
							var is_partition_wall: bool = (dist_x == 6 or dist_z == 6)
							if is_partition_wall:
								# Arch door openings for access at Z=250 or X=-150
								var is_door: bool = (gx == center_x or gz == center_z) and ((wy >= 1 and wy <= 3) or (wy >= 6 and wy <= 8))
								if is_door:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								# Internal rooms spaces
								if wy <= 4: # First Floor Suites
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								elif wy == 5: # Wooden Ceiling divider
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								elif wy <= 8: # Second Floor closed vault rooms!
									# A. PHARAOH'S GOLD VAULT (West Room: X < -156)
									if gx < center_x - 6:
										# High-security pedestal for loot chest
										var is_pedestal: bool = (gx == center_x - 9 and gz == center_z) and (wy == 6)
										if is_pedestal:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								elif wy == 9: # Roof slab
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 3: APEX GLOWING BEACON FARO (Y = base_y + 10 / wy = 10)
			# ==================================================================
			if dist_x <= 1 and dist_z <= 1:
				set_global_block(chunk, offset, gx, base_y + 10, gz, BlockType.Type.STONE)
				if dist_x == 0 and dist_z == 0:
					# Mount high-intensity crystal faro (Glowstone ID 30)
					set_global_block(chunk, offset, gx, base_y + 11, gz, BlockType.Type.GLOWSTONE)


## Concrete Contract: Spawns the central loot chest and defending mummies
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# The Oasis Pyramid Center is at -150, 250.
	# Chunk coordinates match exactly Chunk (-10, 0, 15) for X [-160..-145] and Z [240..255]
	if chunk_pos.x == -10 and chunk_pos.z == 15:
		# 1. PHARAOH'S VAULT CHEST (Placed precisely on top of the Floor 2 Brick Pedestal)
		# Pedestal is at X = -159 (center_x-9), Z = 250, Y = base_y + 6 = 21. 
		# We spawn the chest at Y = 22.0 to rest elegantly on the bricks!
		entities.append({"mob_id": 200, "pos": Vector3(-159.5, 22.0, 250.5)})
		
		# 2. ANCIENT MUMMIES (Zombies protecting the interior maze / Ground Floor Y = 16)
		entities.append({"mob_id": 10, "pos": Vector3(-150.5, 16.0, 246.5)}) # East corridor
		entities.append({"mob_id": 10, "pos": Vector3(-159.5, 16.0, 254.5)}) # West room entrance
		
	return entities
