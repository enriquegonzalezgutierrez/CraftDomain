# ==============================================================================
# Project: CraftDomain
# Description: Upgraded Cinematic MegaStructure representing Steve's Valley Village.
#              Inspirado fielmente en la película de Minecraft.
#              SOLID COMPLIANCE: Adheres strictly to LSP and SRP by encapsulating
#              its own procedural drawing and custom entity spawns.
#              MOUNT CINEMATIC OVERHAUL:
#              - Natural Colossal Arch: Spans a giant 16-block high overgrown 
#                stone arch high above the valley, complete with moss and foliage.
#              - Central Plaza Fountain: Builds a majestic flowing stone water 
#                fountain at the center of the village.
#              - Towering Windmill: Spawns a tall medieval windmill with cloud-wool 
#                sails on a scenic side hill.
#              - Cozy Cliffside Cabins: Houses with tilled golden wheat fields 
#                nestled safely under the giant arch's shade.
#              WARNING FIX: 100% strict static typing to eliminate warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/StevesCabinMegaStructure.gd
# ==============================================================================
class_name StevesCabinMegaStructure
extends IMegaStructure

func _init() -> void:
	# Fixed Coordinates inside the East Golden Bazaar village plains
	global_center = Vector2i(300, -300) 
	bounds_size = Vector2i(60, 60) # Expanded to 60x60 to house the massive valley arch!


## Concrete Implementation: Returns the translation key representing this landmark
func get_name() -> String:
	return "BIOME_STEVES_CABIN" # Key ready for translation


func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 10
	var valley_center_x: int = global_center.x
	var valley_center_z: int = global_center.y
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = gx - valley_center_x
			var dist_z: int = gz - valley_center_z
			
			# ==================================================================
			# PASS 1: SCULPT THE FLAT GREEN VALLEY FLOOR
			# ==================================================================
			for gy in range(0, 31):
				if gy < base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.DIRT)
				elif gy == base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.GRASS)
				else:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
			
			# ==================================================================
			# PASS 2: GENERATE THE MASSIVE OVERGROWN NATURAL STONE ARCH
			# Spans North to South from Z=-20 to Z=+20 with 3 blocks thickness (X)
			# ==================================================================
			if abs(dist_x) <= 1 and abs(dist_z) <= 20:
				# Mathematical parabola for the arch height taper
				var arch_height: int = base_y + 16 - int(pow(float(dist_z), 2.0) / 25.0)
				
				# Build the solid stone arch core (leaving hollow air space below)
				for ay in range(arch_height - 3, arch_height + 1):
					if ay > base_y + 1:
						set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.STONE)
						
						# Overgrow the top of the arch with mossy grass and foliage hanging on edges
						if ay == arch_height:
							set_global_block(chunk, offset, gx, ay, gz, BlockType.Type.GRASS)
							# Random hanging bushes on top
							if (gx + gz) % 3 == 0:
								set_global_block(chunk, offset, gx, ay + 1, gz, BlockType.Type.LEAVES)
			
			# ==================================================================
			# PASS 3: GENERATE THE CENTRAL PLAZA STONE FOUNTAIN (Centered at 0,0)
			# ==================================================================
			if abs(dist_x) <= 2 and abs(dist_z) <= 2:
				var is_border: bool = (abs(dist_x) == 2 or abs(dist_z) == 2)
				
				if is_border:
					# Stone basin rim
					set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.STONE)
				else:
					# Flowing water basin core
					set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WATER)
					
					# Center spout column
					if dist_x == 0 and dist_z == 0:
						set_global_block(chunk, offset, gx, base_y + 2, gz, BlockType.Type.STONE)
						set_global_block(chunk, offset, gx, base_y + 3, gz, BlockType.Type.STONE)
						# Water spilling from the top in 4 directions
						for dx in range(-1, 2):
							for dz in range(-1, 2):
								if abs(dx) != abs(dz):
									set_global_block(chunk, offset, valley_center_x + dx, base_y + 3, valley_center_z + dz, BlockType.Type.WATER)

			# ==================================================================
			# PASS 4: GENERATE THE TOWERING WINDMILL (East hill side)
			# ==================================================================
			if dist_x >= 12 and dist_x <= 14 and dist_z >= 10 and dist_z <= 12:
				var is_wall: bool = (dist_x == 12 or dist_x == 14 or dist_z == 10 or dist_z == 12)
				var mill_base_y: int = base_y
				
				for wy in range(1, 15): # 14 blocks tall
					var ly: int = mill_base_y + wy
					if is_wall:
						set_global_block(chunk, offset, gx, ly, gz, BlockType.Type.STONE)
					else:
						set_global_block(chunk, offset, gx, ly, gz, BlockType.Type.AIR)
						
				# Build the large rotating mill sails at height Y+11 (using CLOUD as wool proxy)
				if dist_x == 13 and dist_z == 10: # Front face
					var axle_y: int = mill_base_y + 11
					set_global_block(chunk, offset, gx, axle_y, gz - 1, BlockType.Type.WOOD) # Axle shaft
					
					# Create 4 majestic diagonal sail blades spanning 4 blocks each
					for i in range(1, 5):
						set_global_block(chunk, offset, gx + i, axle_y + i, gz - 1, BlockType.Type.CLOUD) # Upper Right
						set_global_block(chunk, offset, gx - i, axle_y + i, gz - 1, BlockType.Type.CLOUD) # Upper Left
						set_global_block(chunk, offset, gx + i, axle_y - i, gz - 1, BlockType.Type.CLOUD) # Bottom Right
						set_global_block(chunk, offset, gx - i, axle_y - i, gz - 1, BlockType.Type.CLOUD) # Bottom Left

			# ==================================================================
			# PASS 5: CARVE OAK LOG CABINS (West side under the arch's shade)
			# ==================================================================
			if dist_x >= -12 and dist_x <= -6 and dist_z >= -6 and dist_z <= 0:
				var is_cabin_wall: bool = (dist_x == -12 or dist_x == -6 or dist_z == -6 or dist_z == 0)
				var is_door: bool = (dist_z == 0) and (dist_x == -9) # Entrance face South
				
				for wy in range(1, 6): # Cabin Height: 5 blocks
					if is_cabin_wall:
						if is_door and wy <= 3: 
							continue # Air for door opening
						
						# Create window slots
						var is_window: bool = (wy == 3) and (abs(dist_x + 9) == 3 and dist_z == -3)
						if is_window:
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.AIR)
						else:
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.WOOD) # Solid Log Wall
					else:
						# Empty interior cabin space
						set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.AIR)
						
				# Flat Leaf roof capping the cabin
				for rx in range(-13, -5):
					for rz in range(-7, 2):
						set_global_block(chunk, offset, valley_center_x + rx, base_y + 5, valley_center_z + rz, BlockType.Type.LEAVES)

			# ==================================================================
			# PASS 6: CONSTRUCT COZY WHEAT FIELDS (South of the cabins)
			# ==================================================================
			if dist_x >= -14 and dist_x <= -4 and dist_z >= 4 and dist_z <= 11:
				var is_fence_border: bool = (dist_x == -14 or dist_x == -4 or dist_z == 4 or dist_z == 11)
				
				if is_fence_border:
					# Wooden boundary posts
					if (gx + gz) % 2 == 0:
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WOOD)
				else:
					# Farming plot rows: Alternating water canals and fully mature wheat crop fields!
					var is_water_canal: bool = (dist_x == -11 or dist_x == -9 or dist_x == -6)
					if is_water_canal:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.WATER)
					else:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.DIRT)
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.CROP_RIPE) # Mature gold wheat!


## Spawns Cabin inhabitants dynamically (Steve's companion, Farmer, Golem, and Loot)
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# The Cabin Center (300, -300) falls exactly into chunk (18, 0, -19).
	if chunk_pos.x == 18 and chunk_pos.z == -19:
		# Trader NPC (Merchant) standing inside the fenced cabin yard
		entities.append({"mob_id": 101, "pos": Vector3(302.5, 11.5, -297.5)})
		
		# Farmer NPC tending the tilled agricultural wheat fields
		entities.append({"mob_id": 103, "pos": Vector3(292.5, 11.5, -292.5)})
		
		# --- CINEMATIC GOLEM FORCE SPAWN: Spawn a heavy Iron Golem to protect the valley! ---
		entities.append({"mob_id": 107, "pos": Vector3(300.5, 11.5, -300.5)}) # Right by the central fountain!
		
		# An interactive Loot Chest spawned inside the wooden log cabin
		entities.append({"mob_id": 200, "pos": Vector3(291.5, 11.5, -303.5)})
		
	return entities
