# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructures/DesertOasisMegaStructure.gd
# Description: Handcrafted two-story step-pyramid and oasis sanctuary.
#              Provides structured multi-floor dungeon parameters (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DesertOasisMegaStructure
extends IMegaStructure

# --- PERIMETER & BASELINE GEOMETRY CONSTANTS ---
const PYRAMID_BASE_RADIUS: int = 12       # 24x24 block base
const PYRAMID_HEIGHT: int = 10            # 10-Tiers high stepped pyramid
const BASE_ALTITUDE_Y: int = 15           # Sandy terrain height level
const OASIS_POOL_LIMIT_X: int = 16        # Max water pool size X
const OASIS_POOL_LIMIT_Z: int = 3         # Max water pool size Z

# --- INTERNAL INTERIOR CHAMBER CONSTANTS (RELATIVE TO BASELINE Y) ---
const LEVEL_HOLLOW_HALL: int = 4          # Height limit of Floor 1 sanctuary (Y=19)
const LEVEL_CEILING_DIVISION: int = 5     # Ceiling separator level (Y=20)
const LEVEL_MEZZANINE_CORRIDOR: int = 8   # Height limit of Floor 2 mezzanine (Y=23)
const LEVEL_ROOFTOP_SLAB: int = 9         # Flat roof slab platform (Y=24)
const LEVEL_BEACON_FARO: int = 10         # Beacon base level (Y=25)
const LEVEL_BEACON_CROWN: int = 11        # Crystalline Glowstone bulb (Y=26)

# --- COORDINATES SEGREGATION CONSTANTS ---
const RADIUS_INNER_SANCTUARY: int = 5     # 10x10 central altar room
const LIMIT_WEST_VAULT: int = -6          # Divider wall for Pharaoh's Treasury


func _init() -> void:
	global_center = Vector2i(-150, 250) 
	bounds_size = Vector2i(40, 40)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "STRUCTURE_DESERT_OASIS"


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
			# PASS 1: FLATTEN SANDY OASIS WATER ESTANQUE
			# ==================================================================
			for gy: int in range(0, 32):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < BASE_ALTITUDE_Y - 3:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy < BASE_ALTITUDE_Y:
						chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
					elif gy == BASE_ALTITUDE_Y:
						var is_pool: bool = (dist_x <= OASIS_POOL_LIMIT_X and dist_z <= OASIS_POOL_LIMIT_Z) or (dist_z <= OASIS_POOL_LIMIT_X and dist_x <= OASIS_POOL_LIMIT_Z)
						var is_pyramid_footprint: bool = (dist_x <= PYRAMID_BASE_RADIUS and dist_z <= PYRAMID_BASE_RADIUS)
						
						if is_pool and not is_pyramid_footprint:
							chunk.set_block(lx, ly, lz, BlockType.Type.WATER)
						elif is_pyramid_footprint:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 2: STEPPED SOLID PYRAMID CASING (Y=16 to Y=25)
			# ==================================================================
			for step_y: int in range(1, PYRAMID_HEIGHT + 1):
				var current_y: int = BASE_ALTITUDE_Y + step_y
				var current_radius: int = PYRAMID_BASE_RADIUS - step_y + 1
				
				if dist_x <= current_radius and dist_z <= current_radius:
					var is_outer_casing: bool = (dist_x == current_radius or dist_z == current_radius)
					var is_entrance_gate: bool = (gz == center_z + current_radius) and (dist_x <= 2) and (step_y <= 4)
					
					if is_outer_casing:
						if is_entrance_gate:
							continue
							
						if (gx + gz) % 2 == 0:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.RED_SAND)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
					else:
						# ======================================================
						# INTERNAL CHAMBERS MATHEMATICAL SPACING
						# ======================================================
						var wy: int = step_y # relative height (1 to 10)
						var is_inner_sanctuary: bool = (dist_x <= RADIUS_INNER_SANCTUARY and dist_z <= RADIUS_INNER_SANCTUARY)
						
						if is_inner_sanctuary:
							if wy <= LEVEL_HOLLOW_HALL:
								var is_sarcophagus: bool = (dist_x <= 1 and dist_z <= 1)
								
								if is_sarcophagus:
									if wy == 1: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									elif wy == 2: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
									elif wy == 3: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLOWSTONE)
									else: set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
								elif gz == center_z - 4:
									if gx >= center_x - 5 and gx <= center_x - 2:
										var step_req: int = gx - (center_x - 5) + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									elif gx >= center_x + 2 and gx <= center_x + 5:
										var step_req: int = (center_x + 5) - gx + 1
										if wy <= step_req:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							elif wy == LEVEL_CEILING_DIVISION:
								var is_stair_landing: bool = (gz == center_z - 4) and (abs(gx - center_x) >= 2 and abs(gx - center_x) <= 5)
								var is_open_well: bool = (dist_x <= 3 and dist_z <= 3)
								
								if is_stair_landing or is_open_well:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
									
							elif wy <= LEVEL_MEZZANINE_CORRIDOR:
								var is_fence: bool = (wy == 6) and (dist_x == 4 or dist_z == 4)
								var is_roof_stair: bool = (gz == center_z + 4) and (gx >= center_x - 3 and gx <= center_x + 2)
								
								if is_fence:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_roof_stair:
									var step_req: int = gx - (center_x - 3) + 1
									if (wy - 5) <= step_req:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
							elif wy == LEVEL_ROOFTOP_SLAB:
								var is_hatch_hole: bool = (gz == center_z + 4) and (gx >= center_x + 1 and gx <= center_x + 2)
								if is_hatch_hole:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

						else:
							var is_partition_wall: bool = (dist_x == 6 or dist_z == 6)
							if is_partition_wall:
								var is_door: bool = (gx == center_x or gz == center_z) and ((wy >= 1 and wy <= 3) or (wy >= 6 and wy <= 8))
								if is_door:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								if wy <= LEVEL_HOLLOW_HALL:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								elif wy == LEVEL_CEILING_DIVISION:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								elif wy <= LEVEL_MEZZANINE_CORRIDOR:
									if gx < center_x + LIMIT_WEST_VAULT:
										var is_pedestal: bool = (gx == center_x - 9 and gz == center_z) and (wy == 6)
										if is_pedestal:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.BRICKS)
										else:
											set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									else:
										set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								elif wy == LEVEL_ROOFTOP_SLAB:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 3: APEX GLOWING BEACON FARO (Y = base_y + 10 / wy = 10)
			# ==================================================================
			if dist_x <= 1 and dist_z <= 1:
				set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y + LEVEL_BEACON_FARO, gz, BlockType.Type.STONE)
				if dist_x == 0 and dist_z == 0:
					set_global_block(chunk, offset, gx, BASE_ALTITUDE_Y + LEVEL_BEACON_CROWN, gz, BlockType.Type.GLOWSTONE)


## Concrete Contract: Spawns the central loot chest and defending mummies
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	if chunk_pos.x == -10 and chunk_pos.z == 15:
		# Sarcophagus room coordinates calculated dynamically from relative center
		var chest_pos_x := float(global_center.x - 9) + 0.5 # West Vault (X=-159)
		var chest_pos_y := float(BASE_ALTITUDE_Y + 7)       # Ground level + 7 vertical offset (Y=22)
		var chest_pos_z := float(global_center.y) + 0.5     # Center Z (Z=250)
		entities.append({"mob_id": 200, "pos": Vector3(chest_pos_x, chest_pos_y, chest_pos_z)})
		
		# Spawns tomb defenders symmetrically inside corridors
		var mummy_y := float(BASE_ALTITUDE_Y + 1)
		entities.append({"mob_id": 10, "pos": Vector3(float(global_center.x) + 0.5, mummy_y, float(global_center.y - 4) + 0.5)}) 
		entities.append({"mob_id": 10, "pos": Vector3(float(global_center.x - 9) + 0.5, mummy_y, float(global_center.y + 4) + 0.5)}) 
		
	return entities
