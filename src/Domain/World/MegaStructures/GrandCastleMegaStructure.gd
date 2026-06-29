# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure. A massive 40x40 Stone Castle at X=200, Z=200.
#              DETAILED UPGRADE: Added entrance gates, an ornate throne room,
#              courtyard market stalls, glowing neon lanterns, and NPC populations!
#              MISSION 5 SPAWN: Forces the spawn of a quest Zombie (ID 10) directly 
#              outside the castle gates when "Plains Defender" is active!
#              COLLISION VOID FIX: Adjusted Zombie coordinate strictly to Chunk 13 
#              to prevent it from falling through unloaded collision bounds.
# Author: Enrique González Gutiérrez
# ==============================================================================
class_name GrandCastleMegaStructure
extends IMegaStructure

func _init() -> void:
	global_center = Vector2i(200, 200) 
	bounds_size = Vector2i(60, 60)

func get_name() -> String:
	return "The Grand Stone Castle"

func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 12
	var radius: int = 20 
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = abs(gx - global_center.x)
			var dist_z: int = abs(gz - global_center.y)
			
			# 1. FLATTEN THE GROUND
			for gy in range(0, 31):
				if gy < base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.STONE)
				elif gy == base_y:
					if dist_x <= radius and dist_z <= radius:
						# Stone path from South Gate to the Keep
						if abs(gx - global_center.x) <= 2 and gz >= global_center.y:
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.STONE)
						else:
							set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.GRASS)
					else:
						set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
				else:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
					
			# 2. BUILD OUTER WALLS WITH A GRAND SOUTH GATE
			var is_wall: bool = (dist_x == radius and dist_z <= radius) or (dist_z == radius and dist_x <= radius)
			if is_wall:
				# Open a grand entrance gate on the South wall
				var is_gate: bool = (gz == global_center.y + radius) and (dist_x <= 3)
				for wy in range(1, 9):
					if is_gate and wy <= 5: 
						continue # Leave air for the gate opening!
						
					if wy == 8 and (gx + gz) % 2 == 0:
						continue
					set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE)
					
			# 3. BUILD 4 CYLINDRICAL CORNER TOWERS
			var tower_radius: int = 4
			var is_in_tower: bool = false
			var tx: int = 0
			var tz: int = 0
			
			if abs(gx - (global_center.x - radius)) <= tower_radius and abs(gz - (global_center.y - radius)) <= tower_radius:
				is_in_tower = true; tx = global_center.x - radius; tz = global_center.y - radius
			elif abs(gx - (global_center.x + radius)) <= tower_radius and abs(gz - (global_center.y - radius)) <= tower_radius:
				is_in_tower = true; tx = global_center.x + radius; tz = global_center.y - radius
			elif abs(gx - (global_center.x - radius)) <= tower_radius and abs(gz - (global_center.y + radius)) <= tower_radius:
				is_in_tower = true; tx = global_center.x - radius; tz = global_center.y + radius
			elif abs(gx - (global_center.x + radius)) <= tower_radius and abs(gz - (global_center.y + radius)) <= tower_radius:
				is_in_tower = true; tx = global_center.x + radius; tz = global_center.y + radius
				
			if is_in_tower:
				var t_dist: float = sqrt(pow(gx - tx, 2) + pow(gz - tz, 2))
				if t_dist <= float(tower_radius):
					for wy in range(1, 15):
						if t_dist > float(tower_radius) - 1.5:
							if wy == 14 and (gx + gz) % 2 == 0: continue
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE)
						else:
							if wy == 6 or wy == 12:
								set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.WOOD)
								# Torches inside towers
								if gx == tx and gz == tz and (wy == 7 or wy == 13):
									set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.NEON_CYAN)

			# 4. BUILD CENTRAL KEEP & THRONE ROOM
			var keep_radius: int = 8
			if dist_x <= keep_radius and dist_z <= keep_radius:
				var is_keep_wall: bool = (dist_x == keep_radius or dist_z == keep_radius)
				var is_keep_door: bool = (gz == global_center.y + keep_radius) and (dist_x <= 2)
				
				for wy in range(1, 17):
					if is_keep_wall:
						if is_keep_door and wy <= 4: continue # Keep Entrance
						if wy == 16 and (gx + gz) % 2 == 0: continue
						set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE)
					else:
						# Red Carpet leading to the throne
						if wy == 1 and dist_x <= 1 and gz >= global_center.y - 4:
							set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.RED_SAND)
							
						# The Royal Throne! (Wood and Neon Gold/Magenta accents)
						if gx == global_center.x and gz == global_center.y - 5:
							if wy == 1: set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE) # Base
							if wy == 2: set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.WOOD)  # Seat
							if wy == 3: set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.NEON_MAGENTA) # Crown
							
			# 5. DECORATIONS: COURTYARD MARKET STALLS
			if dist_x == 12 and (dist_z == 5 or dist_z == -5):
				# Wooden table
				set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WOOD)
				set_global_block(chunk, offset, gx, base_y + 2, gz, BlockType.Type.WOOD)
				# Leaves Awning (Toldo)
				for sx in range(-1, 2):
					for sz in range(-1, 2):
						set_global_block(chunk, offset, gx + sx, base_y + 3, gz + sz, BlockType.Type.LEAVES)

## Spawns inhabitants directly into the castle's specific chunks!
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Castle Center is 200, 200. This falls into chunk (12, 0, 12).
	if chunk_pos.x == 12 and chunk_pos.z == 12:
		# Guard next to the throne
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 195.5)})
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 195.5)})
		
		# Merchant at the West courtyard stall
		entities.append({"mob_id": 101, "pos": Vector3(188.5, 13.5, 205.5)})
		# Villager at the East courtyard stall
		entities.append({"mob_id": 100, "pos": Vector3(212.5, 13.5, 195.5)})
		
		# Farmer tending the castle courtyard garden!
		entities.append({"mob_id": 103, "pos": Vector3(200.5, 13.5, 208.5)})
		
		# A special Loot Chest inside the throne room!
		entities.append({"mob_id": 200, "pos": Vector3(196.5, 13.5, 193.5)})
		
	# South Gate is at Z=220, which falls into chunk (12, 0, 13)
	if chunk_pos.x == 12 and chunk_pos.z == 13:
		# Two guards standing exactly outside the massive gate
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 222.5)})
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 222.5)})
		
		# --- MISSION 5 FORCE SPAWN: Spawn the Quest Zombie right outside the gates! ---
		var active_q := QuestService.get_active_quest()
		if active_q != null and active_q.quest_id == "plains_defender":
			# FIXED: Moved safely to Z=218.5 (inside Chunk 13 collision mesh!)
			entities.append({"mob_id": 10, "pos": Vector3(200.0, 13.5, 218.5)})
			print("[GrandCastle] Plains Defender active! Spawning Quest Zombie safely on the bridge.")
		
	return entities
