# ==============================================================================
# Project: CraftDomain
# Description: Domain Service responsible for analyzing macro-scale noise to
#              classify biomes and procedurally select landmark spawn coordinates.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BiomeService.gd
# ==============================================================================
class_name BiomeService
extends RefCounted

## Supported Biomes
enum BiomeType {
	OCEAN,
	PLAINS,
	MOUNTAIN
}

## Supported Architectural Landmarks
enum LandmarkType {
	NONE,
	PORT,       # Spawns near water basins
	VILLAGE,    # Spawns in groups across flat plains
	CASTLE      # Spawns on high mountain peaks
}

## Coordinates classification output structure
class BiomeProfile:
	var biome: BiomeType
	var base_height: int
	var landmark: LandmarkType

## Computes the exact biome and structural profile for any global coordinate.
static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite, biome_noise: FastNoiseLite) -> BiomeProfile:
	var profile := BiomeProfile.new()
	
	# 1. Sample large-scale biome noise [-1..1] (frequency 0.005)
	var b_noise: float = biome_noise.get_noise_2d(float(global_x), float(global_z))
	
	# 2. Classify Biome
	if b_noise < -0.25:
		profile.biome = BiomeType.OCEAN
	elif b_noise < 0.4:
		profile.biome = BiomeType.PLAINS
	else:
		profile.biome = BiomeType.MOUNTAIN
		
	# 3. Sample primary terrain noise and compute height limits based on Biome rules
	var t_noise: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	
	match profile.biome:
		BiomeType.OCEAN:
			# Flat, low-lying water basin
			profile.base_height = int(3.0 + (t_noise + 1.0) * 1.5)
		BiomeType.PLAINS:
			# Smooth, horizontal meadows
			profile.base_height = int(5.0 + (t_noise + 1.0) * 2.0)
		BiomeType.MOUNTAIN:
			# Majestic craggy peaks
			profile.base_height = int(8.0 + (t_noise + 1.0) * 8.0)
			
	# 4. Determine Landmark Spawning (Rare, organic density checks instead of rigid grids)
	profile.landmark = LandmarkType.NONE
	
	# Generate a deterministic pseudo-random factor for this specific coordinate
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	
	match profile.biome:
		BiomeType.OCEAN:
			# Ports: Rare spawn on sandy shore borders (height around 4 or 5)
			if profile.base_height == 4 and spawn_hash % 250 == 42:
				profile.landmark = LandmarkType.PORT
		BiomeType.PLAINS:
			# Villages: Rare clustered spawns across flat meadows
			if spawn_hash % 300 == 13:
				profile.landmark = LandmarkType.VILLAGE
		BiomeType.MOUNTAIN:
			# Castles: Extremely rare spawns on high mountain peaks (height >= 14)
			if profile.base_height >= 14 and spawn_hash % 400 == 7:
				profile.landmark = LandmarkType.CASTLE
				
	return profile
