# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure representing Steve's Workshop & Cabin.
#              Features a cozy oak log house, fenced agricultural fields
#              pre-planted with ripe wheat, and local NPC villagers.
#              SOLID COMPLIANCE: Adheres strictly to LSP and SRP by encapsulating
#              its own procedural drawing and custom entity spawns.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/StevesCabinMegaStructure.gd
# ==============================================================================
class_name StevesCabinMegaStructure
extends IMegaStructure

func _init() -> void:
	# Fixed Coordinates inside the East Golden Bazaar village plains
	global_center = Vector2i(300, -300) 
	bounds_size = Vector2i(40, 40)

func get_name() -> String:
	return "BIOME_STEVES_CABIN" # Key ready for translation

func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 10
	var cabin_center_x: int = global_center.x
	var cabin_center_z: int = global_center.y
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = gx - cabin_center_x
			var dist_z: int = gz - cabin_center_z
			
			# 1. FLATTEN THE FIELDS
			for gy in range(0, 31):
				if gy < base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.DIRT)
				elif gy == base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.GRASS)
				else:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
					
			# 2. CARVE OAK LOG CABIN (Size 6x6, centered slightly north of fields)
			if dist_x >= -3 and dist_x <= 3 and dist_z >= -6 and dist_z <= 0:
				var is_cabin_wall: bool = (dist_x == -3 or dist_x == 3) or (dist_z == -6 or dist_z == 0)
				var is_door: bool = (dist_z == 0) and (dist_x == 0) # Entrance face South
				
				for wy in range(1, 6): # Cabin Height: 5 blocks
					if is_cabin_wall:
						if is_door and wy <= 3: 
							continue # Air for door opening
						
						# Create window slots deterministically on the sides
						var is_window: bool = (wy == 3) and (abs(dist_x) == 3 and dist_z == -3)
						if is_window:
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.AIR)
						else:
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.WOOD) # Solid Log Wall
					else:
						# Empty interior cabin space
						set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.AIR)
						
				# Flat Leaf roof capping the cabin
				for rx in range(-4, 5):
					for rz in range(-7, 2):
						set_global_block(chunk, offset, cabin_center_x + rx, base_y + 5, cabin_center_z + rz, BlockType.Type.LEAVES)

			# 3. CONSTRUCT STEVE'S WHEAT FIELDS (Fenced plots south of the cabin)
			if dist_x >= -8 and dist_x <= 8 and dist_z >= 3 and dist_z <= 12:
				var is_fence_border: bool = (dist_x == -8 or dist_x == 8) or (dist_z == 3 or dist_z == 12)
				
				if is_fence_border:
					# Wooden boundary posts
					if (gx + gz) % 2 == 0:
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WOOD)
				else:
					# Farming plot rows: Alternating water canals and fully mature wheat crop fields!
					var is_water_canal: bool = (dist_x == -4 or dist_x == 0 or dist_x == 4)
					if is_water_canal:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.WATER)
					else:
						set_global_block(chunk, offset, gx, base_y, gz, BlockType.Type.DIRT)
						set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.CROP_RIPE) # Mature gold wheat!

## Spawns Cabin inhabitants dynamically (Steve's companion, Farmer, and Loot)
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# The Cabin Center (300, -300) falls exactly into chunk (18, 0, -19).
	if chunk_pos.x == 18 and chunk_pos.z == -19:
		# Trader NPC (Merchant) standing inside the fenced cabin yard
		entities.append({"mob_id": 101, "pos": Vector3(302.5, 11.5, -297.5)})
		
		# Farmer NPC tending the pre-planted dynamic wheat fields
		entities.append({"mob_id": 103, "pos": Vector3(296.5, 11.5, -294.5)})
		
		# An interactive Loot Chest spawned inside the wooden log cabin
		entities.append({"mob_id": 200, "pos": Vector3(298.5, 11.5, -303.5)})
		
	return entities
