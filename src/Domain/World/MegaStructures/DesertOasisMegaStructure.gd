# ==============================================================================
# Project: CraftDomain
# Description: Concrete MegaStructure. A massive Desert Step-Pyramid and Oasis
#              situated in the South-West Red Badlands.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric generation and entity placements for this specific POI.
#              - Liskov Substitution Principle (LSP): Fully implements IMegaStructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructures/DesertOasisMegaStructure.gd
# ==============================================================================
class_name DesertOasisMegaStructure
extends IMegaStructure

func _init() -> void:
	# Fixed coordinates in the South-West quadrant (Desert Canyons)
	global_center = Vector2i(-150, 250) 
	bounds_size = Vector2i(40, 40)


## Concrete Implementation: Returns the translation key representing this landmark
func get_name() -> String:
	return "STRUCTURE_DESERT_OASIS"


## Concrete Implementation: Carves the terrain and builds the steps
func build_chunk(chunk: Chunk, offset: Vector3i) -> void:
	var base_y: int = 15
	var center_x: int = global_center.x
	var center_z: int = global_center.y
	
	var min_x: int = global_center.x - int(bounds_size.x / 2.0)
	var max_x: int = global_center.x + int(bounds_size.x / 2.0)
	var min_z: int = global_center.y - int(bounds_size.y / 2.0)
	var max_z: int = global_center.y + int(bounds_size.y / 2.0)
	
	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var dist_x: int = abs(gx - center_x)
			var dist_z: int = abs(gz - center_z)
			
			# Declare local chunk coordinates at parent scope to prevent compile-time shadowing
			var lx: int = gx - offset.x
			var lz: int = gz - offset.z
			
			# 1. FLATTEN THE GROUND & PLACE OASIS WATER
			for gy in range(0, 32):
				var ly := gy - offset.y
				
				if chunk.is_within_bounds(lx, ly, lz):
					if gy < base_y:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
					elif gy == base_y:
						# Create a large cross-shaped water pool around the pyramid structure
						if (dist_x <= 16 and dist_z <= 3) or (dist_z <= 16 and dist_x <= 3):
							chunk.set_block(lx, ly, lz, BlockType.Type.WATER)
						else:
							chunk.set_block(lx, ly, lz, BlockType.Type.SAND)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
						
			# 2. BUILD THE GIANT STEP-PYRAMID (Center)
			var max_radius: int = 12
			if dist_x <= max_radius and dist_z <= max_radius:
				for step in range(0, 8):
					var step_radius: int = max_radius - step
					var py: int = base_y + 1 + step
					
					if dist_x <= step_radius and dist_z <= step_radius:
						var is_edge: bool = (dist_x == step_radius or dist_z == step_radius)
						if is_edge:
							# Edge decorative detailing utilizing new Oak Planks and Red Sandstone
							if (gx + gz) % 2 == 0:
								chunk.set_block(lx, py, lz, BlockType.Type.OAK_PLANKS)
							else:
								chunk.set_block(lx, py, lz, BlockType.Type.RED_SAND)
						else:
							# Hollow interior for player exploration on lower layers
							if step == 0:
								chunk.set_block(lx, py, lz, BlockType.Type.SAND)
							else:
								chunk.set_block(lx, py, lz, BlockType.Type.AIR)
								
			# 3. BUILD APEX ALTAR (Glowing tip)
			if dist_x <= 2 and dist_z <= 2:
				set_global_block(chunk, offset, gx, base_y + 9, gz, BlockType.Type.STONE)
				if dist_x == 0 and dist_z == 0:
					# Mount the bright glowing gem (Glowstone) on top
					set_global_block(chunk, offset, gx, base_y + 10, gz, BlockType.Type.GLOWSTONE)


## Concrete Implementation: Spawns the central loot chest and defending mummies
func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	# The Oasis Pyramid Center is at -150, 250 (Chunk -10, 0, 15)
	if chunk_pos.x == -10 and chunk_pos.z == 15:
		# Secret Loot Chest hidden directly inside the base hollow pyramid core
		entities.append({"mob_id": 200, "pos": Vector3(-150.5, 16.5, 250.5)})
		
		# Mummy guardians (Zombies) patrolling the left and right pyramid sand boundaries
		entities.append({"mob_id": 10, "pos": Vector3(-142.5, 16.5, 250.5)})
		entities.append({"mob_id": 10, "pos": Vector3(-158.5, 16.5, 250.5)})
		
	return entities
