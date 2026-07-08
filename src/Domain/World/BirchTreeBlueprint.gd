# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a slender, silver-barked Birch Tree.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the growth ratios, 
#   height parameters, and branching coordinates specific to the Birch tree species.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Birch-specific 
#   growth parameters are closed to modifications from other trees.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'ProceduralTools'.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BirchTreeBlueprint.gd
# ==============================================================================
class_name BirchTreeBlueprint
extends IStructureBlueprint

# Birch Biological Constants
const TRUNK_BLOCK := BlockType.Type.BIRCH_LOG
const LEAVES_BLOCK := BlockType.Type.LEAVES

const MIN_HEIGHT: int = 6
const MAX_HEIGHT: int = 9
const LEAN_FACTOR: float = 0.15 # Slender growth, lower lean walk
const BRANCH_CHANCE: float = 0.25
const MAX_BRANCHES: int = 2
const LEAF_RADIUS: float = 2.2 # Tighter canopy profile


## Concrete Implementation: Returns the unique structure ID for the Birch Tree (ID 13)
func get_structure_id() -> int:
	return 13


## Concrete Implementation: Grows a slender birch tree with silver trunk, high branches, and compact leaf spheres
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Seed local RNG based on coordinates for reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine height for this specific instance
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# 2. Grow Slender Trunk
	for h in range(height):
		current_pos.y += 1.0
		# Narrow lean threshold to simulate upright growth
		if h > 3 and rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		ProceduralTools.set_block_safe(chunk, node, TRUNK_BLOCK)
		
	# 3. High-Height Branching (Occurs only in the upper 30% segment of the trunk)
	var split_index := int(float(trunk_nodes.size()) * 0.7)
	var leaf_hubs: Array[Vector3i] = []
	
	# Pinnacle leaf hub
	leaf_hubs.append(trunk_nodes.back())
	
	var branches_spawned := 0
	for i in range(split_index, trunk_nodes.size() - 1):
		if branches_spawned >= MAX_BRANCHES:
			break
			
		if rng.randf() < BRANCH_CHANCE:
			var branch_origin := trunk_nodes[i]
			
			# Project slender, vertical-tending branch vectors
			var angle := rng.randf() * TAU
			var direction_vector := Vector3(cos(angle), rng.randf_range(0.5, 0.9), sin(angle)).normalized()
			var branch_length := rng.randi_range(1, 3)
			
			var branch_pos := Vector3(branch_origin)
			for b in range(branch_length):
				branch_pos += direction_vector
				var b_node := Vector3i(int(round(branch_pos.x)), int(round(branch_pos.y)), int(round(branch_pos.z)))
				ProceduralTools.set_block_safe(chunk, b_node, TRUNK_BLOCK)
				
				if b == branch_length - 1:
					leaf_hubs.append(b_node)
					
			branches_spawned += 1
			
	# 4. Sculpt Compact Leaf Clouds
	for hub in leaf_hubs:
		ProceduralTools.sculpt_leaf_sphere(chunk, hub, LEAF_RADIUS, rng)
