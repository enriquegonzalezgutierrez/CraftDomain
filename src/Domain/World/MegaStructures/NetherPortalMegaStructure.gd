# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure representing an ancient Nether Outpost.
#              Features a massive glowing obsidian Nether Portal, lava rivers,
#              and red netherrack ramparts.
#              SOLID COMPLIANCE: Adheres strictly to LSP and SRP by encapsulating
#              its own procedural drawing and custom entity spawns.
#              FIX: Removed unused "is_frame_edge" local variable to clear compiler warning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/NetherPortalMegaStructure.gd
# ==============================================================================
class_name NetherPortalMegaStructure
extends IMegaStructure

func _init() -> void:
	# Fixed far North-West coordinates inside the Craggy Peaks border
	global_center = Vector2i(-300, -300) 
	bounds_size = Vector2i(50, 50)

func get_name() -> String:
	return "BIOME_NETHER_OUTPOST" # Key ready for translation

func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 8
	var portal_center_x: int = global_center.x
	var portal_center_z: int = global_center.y
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = abs(gx - portal_center_x)
			var dist_z: int = abs(gz - portal_center_z)
			
			# 1. SCULPT NETHERRACK GROUND (Using Red Sand for a burnt, nether-like soil)
			for gy in range(0, 31):
				if gy < base_y - 2:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.STONE)
				elif gy < base_y:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.RED_SAND) # Netherrack ground
				elif gy == base_y:
					# Create dynamic lava streams radiating from the portal
					if (dist_x == 3 or dist_x == 4) and gz >= portal_center_z - 15 and gz <= portal_center_z + 15:
						set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.LAVA)
					else:
						set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.RED_SAND)
				else:
					set_global_block(chunk, offset, gx, gy, gz, BlockType.Type.AIR)
					
			# 2. BUILD NETHER FORTRESS BRICK WALLS
			var is_wall: bool = (dist_x == 16 and dist_z <= 16) or (dist_z == 16 and dist_x <= 16)
			if is_wall:
				for wy in range(1, 6):
					# Leave a few broken gaps for a ruined fortress aesthetic
					if (gx + gz + wy) % 9 == 0:
						continue
					set_global_block(chunk, offset, gx, base_y + wy, gz, BlockType.Type.STONE) # Fortress bricks
					
			# 3. BUILD THE MASSIVE NETHER PORTAL (Centered at global_center)
			if dist_z == 0 and dist_x <= 4:
				# Portal frame: 9 blocks wide (X: -4 to +4), 7 blocks high (Y: base_y to +7)
				for py in range(0, 8):
					var is_outer_rim: bool = (abs(gx - portal_center_x) == 4) or (py == 0) or (py == 7)
					
					if is_outer_rim:
						# Portal Frame: Made of Obsidian (represented by Stone)
						set_global_block(chunk, offset, gx, base_y + py, gz, BlockType.Type.STONE)
					else:
						# Portal Purple Energy: Made of Neon Magenta
						set_global_block(chunk, offset, gx, base_y + py, gz, BlockType.Type.NEON_MAGENTA)
						
				# Add auxiliary lava fonts behind the portal frame for dramatic lighting
				if abs(gx - portal_center_x) == 5:
					set_global_block(chunk, offset, gx, base_y + 1, gz, BlockType.Type.LAVA)

## Spawns Nether defenders (Zombies) inside the fortress chunks dynamically
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	
	# The Nether Portal Center (-300, -300) falls exactly into chunk (-19, 0, -19).
	if chunk_pos.x == -19 and chunk_pos.z == -19:
		# Nether Guards (Zombies) patrolling the Obsidian Portal
		entities.append({"mob_id": 10, "pos": Vector3(-295.5, 9.5, -298.5)})
		entities.append({"mob_id": 10, "pos": Vector3(-304.5, 9.5, -298.5)})
		
		# A secret Nether Loot Chest hidden behind the portal frame
		entities.append({"mob_id": 200, "pos": Vector3(-300.5, 9.5, -302.5)})
		
	return entities
