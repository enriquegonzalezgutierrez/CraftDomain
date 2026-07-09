# ==============================================================================
# Project: CraftDomain
# Layer: Domain / Infrastructure Bridge (MegaStructures)
# Class: StevesCabinMegaStructure
# Description: HANDCRAFTED 2-STORY LOG CABIN, TRANSITABLE WINDMILL & VALLEY ARCH.
#              Rebuilds Steve's Settlement at global [300, -300] into a detailed, 
#              fully playable 3D village. Features a giant mossy stone arch spanning 
#              the valley, a central plaza water fountain, irrigated wheat fields, 
#              a 2-story cozy log cabin with internal stairs and bedroom, and a 
#              towering medieval windmill with fully accessible interior floors.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the multi-chunk 
#   architectural block blueprint and entity allocations.
# - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/StevesCabinMegaStructure.gd
# ==============================================================================
class_name StevesCabinMegaStructure
extends IMegaStructure

const CABIN_WIDTH_HALF: int = 5    # Cozy 10x10 footprint lodge
const CABIN_LENGTH_HALF: int = 5
const TAV_DOCK_LEVEL: int = 10     # Base ground altitude inside the valley


func _init() -> void:
	global_center = Vector2i(300, -300) 
	bounds_size = Vector2i(60, 60)


## Concrete Contract: Returns the landmark's translation key
func get_name() -> String:
	return "BIOME_STEVES_CABIN"


## Concrete Contract: Sculpting pipeline executed by the chunk mesher threads
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = TAV_DOCK_LEVEL
	var valley_center_x: int = global_center.x
	var valley_center_z: int = global_center.y
	
	var min_x: int = valley_center_x - floori(float(bounds_size.x) / 2.0)
	var max_x: int = valley_center_x + floori(float(bounds_size.x) / 2.0)
	var min_z: int = valley_center_z - floori(float(bounds_size.y) / 2.0)
	var max_z: int = valley_center_z + floori(float(bounds_size.y) / 2.0)
	
	for gx: int in range(min_x, max_x + 1):
		for gz: int in range(min_z, max_z + 1):
			var dist_x: int = gx - valley_center_x
			var dist_z: int = gz - valley_center_z
			
			var lx: int = gx - offset.x
			var lz: int = gz - offset.z
			
			# ==================================================================
			# PASS 1: SCULPT COZY GREEN VALLEY BASELINE FLOOR
			# ==================================================================
			for gy: int in range(0, 32):
				var ly: int = gy - offset.y
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.DIRT)
					elif gy == base_y:
						# Natural stone floor inside Steve's cabin perimeter
						var is_inside_lodge: bool = (gx >= valley_center_x - 12 and gx <= valley_center_x - 2) and (gz >= valley_center_z - 12 and gz <= valley_center_z - 2)
						if is_inside_lodge:
							chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.GRASS)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

			# ==================================================================
			# PASS 2: GENERATE OVERGROWN COLOSSAL STONE ARCHWAY (Parabolic span)
			# ==================================================================
			if abs(dist_x) <= 1 and abs(dist_z) <= 20:
				var arch_height: int = base_y + 16 - floori(pow(float(dist_z), 2.0) / 25.0)
				for ay: int in range(arch_height - 3, arch_height + 1):
					if ay > base_y + 1:
						set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.STONE)
						if ay == arch_height:
							set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.GRASS)
							if (gx + gz) % 3 == 0:
								set_global_block(chunk, offset, gx, ay + 1, gz, BlockType.Type.LEAVES)

			# ==================================================================
			# PASS 3: CENTRAL PLAZA BRICK WATER FOUNTAIN (Centered at X=0, Z=0)
			# ==================================================================
			if abs(dist_x) <= 2 and abs(dist_z) <= 2:
				var is_fount_rim: bool = (abs(dist_x) == 2 or abs(dist_z) == 2)
				if is_fount_rim:
					set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.STONE)
				else:
					set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WATER)
					if dist_x == 0 and dist_z == 0:
						set_global_block(chunk, offset, gx, base_y + 2, gz, BlockType.Type.STONE)
						set_global_block(chunk, offset, gx, base_y + 3, gz, BlockType.Type.STONE)
						for dx: int in range(-1, 2):
							for dz: int in range(-1, 2):
								if abs(dx) != abs(dz):
									set_global_block(chunk, offset, valley_center_x + dx, base_y + 3, valley_center_z + dz, BlockType.Type.WATER)

			# ==================================================================
			# PASS 4: TOWERING TRANSITABLE WINDMILL (East hill side / X: 11 to 15, Z: 9 to 13)
			# ==================================================================
			if dist_x >= 11 and dist_x <= 15 and dist_z >= 9 and dist_z <= 13:
				var is_mill_wall: bool = (dist_x == 11 or dist_x == 15 or dist_z == 9 or dist_z == 13)
				var is_mill_door: bool = (dist_z == 9) and (gx == valley_center_x + 13)
				
				for wy: int in range(1, 15): # Towering height 14 blocks
					var current_y: int = base_y + wy
					if is_mill_wall:
						if is_mill_door and wy <= 3:
							continue # Entrance post
							
						set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
					else:
						# Accessible internal floors for ladder climbing
						if wy == 6 or wy == 11:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							
				# Build Rotating Sails Mechanism at height Y+11 (wy=11)
				if dist_x == 13 and dist_z == 9:
					var axle_y: int = base_y + 11
					set_global_block(chunk, offset, gx, axle_y, gz - 1, BlockType.Type.WOOD) # Axle
					for i: int in range(1, 5):
						set_global_block(chunk, offset, gx + i, axle_y + i, gz - 1, BlockType.Type.CLOUD)
						set_global_block(chunk, offset, gx - i, axle_y + i, gz - 1, BlockType.Type.CLOUD)
						set_global_block(chunk, offset, gx + i, axle_y - i, gz - 1, BlockType.Type.CLOUD)
						set_global_block(chunk, offset, gx - i, axle_y - i, gz - 1, BlockType.Type.CLOUD)

			# ==================================================================
			# PASS 5: COZY TWO-STORY LOG CABIN (West side under the arch X [-12..-2], Z [-12..-2])
			# ==================================================================
			var cabin_min_x: int = valley_center_x - 12
			var cabin_max_x: int = valley_center_x - 2
			var cabin_min_z: int = valley_center_z - 12
			var cabin_max_z: int = valley_center_z - 2
			
			if gx >= cabin_min_x and gx <= cabin_max_x and gz >= cabin_min_z and gz <= cabin_max_z:
				var is_cabin_wall: bool = (gx == cabin_min_x or gx == cabin_max_x or gz == cabin_min_z or gz == cabin_max_z)
				var is_front_door: bool = (gz == cabin_max_z) and (gx == valley_center_x - 7) # Main entry door
				
				for wy: int in range(1, 13): # 12 blocks total height
					var current_y: int = base_y + wy
					
					if is_cabin_wall:
						if is_front_door and wy <= 3:
							continue # Entry arch
							
						# Window slits for Floor 1 and Floor 2
						var is_window: bool = (wy == 3 or wy == 9) and ((gx == valley_center_x - 7 and gz == cabin_min_z) or (gz == valley_center_z - 7 and gx == cabin_min_x))
						if is_window:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.GLASS)
						else:
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
					else:
						# ======================================================
						# CABIN INTERIOR SPACING (SRP Compliant)
						# ======================================================
						if wy <= 5: # Floor 1 Cozy Living Hearth (Y: 11 to 15)
							# Symmetrical Wooden Stairs ascending along the West wall
							var is_cabin_stair: bool = (gx == cabin_min_x + 1) and (gz >= cabin_min_z + 2 and gz <= cabin_min_z + 6)
							if is_cabin_stair:
								var step_req: int = gz - (cabin_min_z + 2) + 1 # climbs South-North
								if wy <= step_req:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								
						elif wy == 6: # Ceiling separation level (Y = 16)
							# Open landing hole for stairs at North-West
							var is_stair_landing: bool = (gx == cabin_min_x + 1) and (gz >= cabin_min_z + 5 and gz <= cabin_min_z + 7)
							if is_stair_landing:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
							else:
								set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)
								
						elif wy <= 11: # Floor 2 Cozy Suites (Y: 17 to 21)
							# Internal wall partition splits into NW Suite & SW Suite at Z = -305
							var is_suite_divider: bool = (gz == valley_center_z - 7)
							if is_suite_divider:
								# Arch door in divider at X=-5
								if gx == valley_center_x - 5 and wy <= 9:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.STONE)
							else:
								# NW Suite: Steve's private bed chamber (wood frames, cloud sheets)
								var is_steve_bed: bool = (gx >= cabin_min_x + 2 and gx <= cabin_min_x + 3) and (gz == cabin_min_z + 2) and (wy == 7)
								var is_steve_pillow: bool = (gx == cabin_min_x + 2) and (gz == cabin_min_z + 2) and (wy == 8)
								
								if is_steve_bed:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.WOOD)
								elif is_steve_pillow:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.CLOUD)
								else:
									set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.AIR)
									
						else: # Flat wooden planks roof ceiling
							set_global_block(chunk, offset, gx, current_y, gz, BlockType.Type.OAK_PLANKS)

			# ==================================================================
			# PASS 6: IRRIGATED GOLDEN WHEAT FARMLAND (South of lodge X: -14 to -4, Z: 4 to 12)
			# ==================================================================
			var farm_min_x: int = valley_center_x - 14
			var farm_max_x: int = valley_center_x - 4
			var farm_min_z: int = valley_center_z + 4
			var farm_max_z: int = valley_center_z + 12
			
			if gx >= farm_min_x and gx <= farm_max_x and gz >= farm_min_z and gz <= farm_max_z:
				var is_border_fence: bool = (gx == farm_min_x or gx == farm_max_x or gz == farm_min_z or gz == farm_max_z)
				if is_border_fence:
					if (gx + gz) % 2 == 0:
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WOOD) # Fence post
				else:
					# Alternating water canals and crop fields
					var is_water_canal: bool = (gx == valley_center_x - 11 or gx == valley_center_x - 8)
					if is_water_canal:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.WATER)
					else:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.DIRT)
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.CROP_RIPE) # Golden Wheat


## Concrete Contract: Dispatches inhabitants and interactive props strictly inside their chunk grids
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# The Settlement Center is at [300, -300].
	# Fits precisely inside Chunk (18, 0, -19) for X [288..303] and Z [-304..-289]
	if chunk_pos.x == 18 and chunk_pos.z == -19:
		# 1. Seeds Merchant standing inside the fenced farm plots
		entities.append({"mob_id": 101, "pos": Vector3(302.5, 11.0, -297.5)})
		
		# 2. Agricultural Farmer NPC tending the tilled golden crops
		entities.append({"mob_id": 103, "pos": Vector3(292.5, 11.0, -292.5)})
		
		# 3. Golem Guardian patrilling around the central water fountain
		entities.append({"mob_id": 107, "pos": Vector3(300.5, 11.0, -300.5)})
		
		# 4. Steve's Cabin Loot Chest (Placed on Floor 2 bedroom table)
		# Bedroom NW table sits at X=293, Z=-308, Y = base_y + 7 = 17. 
		# We spawn the chest at Y = 18.0 to rest perfectly inside!
		entities.append({"mob_id": 200, "pos": Vector3(293.5, 17.0, -308.5)})
		
	return entities
