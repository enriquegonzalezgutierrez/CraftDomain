# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure. A Harbor with a massive Galleon Ship.
#              DETAILED UPGRADE: Added a Captain's cabin, stacked crates, 
#              and populated the docks with a Merchant and Guards!
# Author: Enrique González Gutiérrez
# ==============================================================================
class_name HarborCityMegaStructure
extends IMegaStructure

func _init() -> void:
	global_center = Vector2i(-150, 0) # FIXED COORDINATES!
	bounds_size = Vector2i(50, 40)

func get_name() -> String:
	return "The Port of Sails & Galleon"

func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var water_level: int = 5
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = gx - global_center.x
			var dist_z: int = gz - global_center.y
			
			# 1. FORCE WATER BASIN
			for gy in range(0, 31):
				if gy < water_level - 3:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.SAND)
				elif gy <= water_level:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WATER)
				else:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
					
			# 2. BUILD WOODEN DOCKS AND CRATES
			if dist_x > 5 and dist_x < 20 and abs(dist_z) < 8:
				if (gx + gz) % 4 == 0:
					for gy in range(1, water_level + 2):
						set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
				set_global_block(chunk, offset, gx, water_level + 1, gz, BlockType.Type.WOOD)
				
				# Stacked Crates (Cajas de madera en el muelle)
				if gx == global_center.x + 12 and abs(dist_z) == 3:
					set_global_block(chunk, offset, gx, water_level + 2, gz, BlockType.Type.WOOD)
					if dist_z == 3: # Stack higher on one side
						set_global_block(chunk, offset, gx, water_level + 3, gz, BlockType.Type.WOOD)
				
			# 3. BUILD THE GALLEON SHIP (Centered)
			if dist_x >= -12 and dist_x <= 12 and abs(dist_z) <= 5:
				var bow_taper: float = float(abs(dist_z)) / 5.0
				var hull_curve: float = 12.0 - (bow_taper * 4.0)
				
				if float(abs(dist_x)) <= hull_curve:
					for gy in range(water_level - 1, water_level + 1):
						set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
						
					var is_hull_edge: bool = float(abs(dist_x)) > (hull_curve - 1.0) or abs(dist_z) == 5
					for gy in range(water_level - 1, water_level + 4):
						if gy == water_level - 1: 
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
						elif is_hull_edge: 
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
							
					# Deck Floor
					set_global_block(chunk, offset, gx, water_level + 2, gz, BlockType.Type.WOOD)
					
					# Captain's Cabin at the back (Stern)
					if dist_x >= 7 and dist_x <= 11 and abs(dist_z) <= 3:
						var is_cabin_wall: bool = dist_x == 7 or dist_x == 11 or abs(dist_z) == 3
						for gy in range(water_level + 3, water_level + 6):
							if is_cabin_wall:
								# Windows in the cabin
								if gy == water_level + 4 and dist_x == 11 and dist_z == 0: continue
								set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
							elif gy == water_level + 5: # Roof
								set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
					
					# 3 Masts & Sails
					if dist_z == 0 and (dist_x == -8 or dist_x == 0 or dist_x == 8):
						for gy in range(water_level + 3, water_level + 18):
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.WOOD)
						for gy in range(water_level + 6, water_level + 15):
							var sail_width: int = 15 - gy
							if sail_width > 4: sail_width = 4
							for sz in range(-sail_width, sail_width + 1):
								set_global_block(chunk, offset, gx - 1, gy, gz + sz, BlockType.Type.CLOUD)

## Spawns Harbor and Ship inhabitants
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Harbor Center is -150, 0. This falls into chunk (-10, 0, 0).
	if chunk_pos.x == -10 and chunk_pos.z == 0:
		# Merchant standing on the docks waiting for goods
		entities.append({"mob_id": 101, "pos": Vector3(-136.5, 7.5, 0.5)})
		
		# Harbor Guard patrolling the dock edge
		entities.append({"mob_id": 102, "pos": Vector3(-131.5, 7.5, -4.5)})
		
		# Villager inspecting the wood crates
		entities.append({"mob_id": 100, "pos": Vector3(-138.5, 7.5, 3.5)})
		
		# Ship Captain (Guard model) standing at the helm of the Galleon
		entities.append({"mob_id": 102, "pos": Vector3(-144.5, 8.5, 0.5)})
		
		# Loot Chest hidden inside the Captain's Cabin!
		entities.append({"mob_id": 200, "pos": Vector3(-140.5, 8.5, 0.5)})
		
	return entities
