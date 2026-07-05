# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure. A massive 40x40 Stone Castle at X=200, Z=200.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Sculpting and POI bounds.
#              - Liskov Substitution Principle (LSP): Implements IMegaStructure.
#              COLLISION VOID RESOLUTION:
#              - Distributed entity spawning to match exact chunk boundaries.
#                This prevents entities from spawning over unloaded chunks, resolving
#                the bug where NPCs would fall through the void and disappear.
#              ATMOSPHERIC CASTLE LIGHTING OVERHAUL:
#              - Built 4 massive 9-block high glowing Neon-Cyan columns in the 4 corners 
#                of the interior Throne Room to light up the palace.
#              - Injected 4 real-time light-emitting Streetlight props (ID 202) symmetrically 
#                flanking the Royal Throne and illuminating the outer merchants courtyard at night.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/GrandCastleMegaStructure.gd
# ==============================================================================
class_name GrandCastleMegaStructure
extends IMegaStructure

func _init() -> void:
	global_center = Vector2i(200, 200) 
	bounds_size = Vector2i(60, 60)


## Concrete Implementation: Returns the translation key representing this landmark
func get_name() -> String:
	return "STRUCTURE_GRAND_CASTLE"


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
			for gy in range(0, 32):
				var lx := gx - offset.x
				var ly := gy - offset.y
				var lz := gz - offset.z
				
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy == base_y:
						if dist_x <= radius and dist_z <= radius:
							# Stone path from South Gate to the Keep
							if abs(gx - global_center.x) <= 2 and gz >= global_center.y:
								chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
							else:
								chunk.set_block(lx, ly, lz, BlockType.Type.GRASS)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					
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
							
						# ORNATE NEON-CYAN LIGHT COLUMNS:
						# Build 4 glowing columns in the 4 corners of the interior Throne Room (height 9)
						if abs(dist_x) == 6 and abs(dist_z) == 6:
							if wy == 1 or wy == 9:
								set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE) # Carved stone base/cap
							elif wy < 9:
								set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.NEON_CYAN) # Glowing crystal core!

			# 5. DECORATIONS: COURTYARD MARKET STALLS
			if dist_x == 12 and (dist_z == 5 or dist_z == -5):
				# Wooden table
				set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.WOOD)
				set_global_block(chunk, offset, gx, base_y + 2, gz, BlockType.Type.WOOD)
				# Leaves Awning (Toldo)
				for sx in range(-1, 2):
					for sz in range(-1, 2):
						set_global_block(chunk, offset, gx + sx, base_y + 3, gz + sz, BlockType.Type.LEAVES)


## Spawns inhabitants and physical light entities inside the castle chunks
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# Castle Center is 200, 200. We distribute entity coordinates strictly inside their matching chunks
	# to avoid physical spawn interpenetration / void-falling bugs on chunk edges.
	
	# --- CHUNK (12, 0, 12) ---
	# Bounds: X [192, 207], Z [192, 207]
	if chunk_pos.x == 12 and chunk_pos.z == 12:
		# Guards next to the throne
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 195.5)})
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 195.5)})
		
		# A special Loot Chest inside the throne room!
		entities.append({"mob_id": 200, "pos": Vector3(196.5, 13.5, 193.5)})
		
		# Symmetrical Streetlights flanking the Royal Throne
		entities.append({"mob_id": 202, "pos": Vector3(196.5, 13.5, 196.5)}) # Left Throne Lamp
		entities.append({"mob_id": 202, "pos": Vector3(203.5, 13.5, 196.5)}) # Right Throne Lamp
		
	# --- CHUNK (11, 0, 12) ---
	# Bounds: X [176, 191], Z [192, 207]
	elif chunk_pos.x == 11 and chunk_pos.z == 12:
		# Merchant at the West courtyard stall (In bounds: X=190.5)
		entities.append({"mob_id": 101, "pos": Vector3(190.5, 13.0, 205.5)})
		
	# --- CHUNK (13, 0, 12) ---
	# Bounds: X [208, 223], Z [192, 207]
	elif chunk_pos.x == 13 and chunk_pos.z == 12:
		# Villager at the East courtyard stall (First Quest Target: X=210.5)
		entities.append({"mob_id": 100, "pos": Vector3(210.5, 13.0, 195.5)})
		
	# --- CHUNK (12, 0, 13) ---
	# Bounds: X [192, 207], Z [208, 223]
	elif chunk_pos.x == 12 and chunk_pos.z == 13:
		# Two guards standing exactly outside the massive South Gate
		entities.append({"mob_id": 102, "pos": Vector3(197.5, 13.5, 222.5)})
		entities.append({"mob_id": 102, "pos": Vector3(202.5, 13.5, 222.5)})
		
		# Farmer tending the castle courtyard garden (In bounds: Z=208.5)
		entities.append({"mob_id": 103, "pos": Vector3(200.5, 13.5, 208.5)})
		
		# --- MISSION 5 FORCE SPAWN: Spawn the Quest Zombie right outside the gates! ---
		var active_q := QuestService.get_active_quest()
		if active_q != null and active_q.quest_id == "plains_defender":
			entities.append({"mob_id": 10, "pos": Vector3(200.0, 13.5, 218.5)})
			print("[GrandCastle] Plains Defender active! Spawning Quest Zombie safely on the bridge.")
			
	# --- CHUNK (11, 0, 13) ---
	# Bounds: X [176, 191], Z [208, 223]
	elif chunk_pos.x == 11 and chunk_pos.z == 13:
		# West Courtyard Lamp (In bounds: X=188.5, Z=208.5)
		entities.append({"mob_id": 202, "pos": Vector3(188.5, 13.5, 208.5)})
		
	# --- CHUNK (13, 0, 13) ---
	# Bounds: X [208, 223], Z [208, 223]
	elif chunk_pos.x == 13 and chunk_pos.z == 13:
		# East Courtyard Lamp (In bounds: X=212.5, Z=208.5)
		entities.append({"mob_id": 202, "pos": Vector3(212.5, 13.5, 208.5)})
		
	return entities
