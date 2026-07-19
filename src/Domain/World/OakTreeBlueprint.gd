# ==============================================================================
# Pathfile: res://src/Domain/World/OakTreeBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a highly organic, branching Oak Tree.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the growth ratios, 
#   height parameters, and branching coordinates specific to the Oak tree species.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'VoxelGeometricSculptor'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OakTreeBlueprint
extends IStructureBlueprint

# Oak Biological Constants
const TRUNK_BLOCK := BlockType.Type.WOOD
const LEAVES_BLOCK := BlockType.Type.LEAVES

const MIN_HEIGHT: int = 5
const MAX_HEIGHT: int = 8
const LEAN_FACTOR: float = 0.35
const BRANCH_CHANCE: float = 0.45
const MAX_BRANCHES: int = 3
const LEAF_RADIUS: float = 2.8


## Concrete Implementation: Returns the unique structure ID for the Oak Tree (ID 1)
func get_structure_id() -> int:
	return 1


## Concrete Implementation: Grows an organic oak tree with leaning trunk, branches, and leaf spheres
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Seed local RNG based on coordinates for reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine height for this specific instance
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# 2. Grow Organic Leaning Trunk
	for h in range(height):
		current_pos.y += 1.0
		# Apply gradual lean walk after base grounding blocks
		if h > 2 and rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		VoxelGeometricSculptor.set_block_safe(chunk, node, TRUNK_BLOCK)
		
	# 3. Branching Bifurcation (Upper 40% height segment)
	var split_index := int(float(trunk_nodes.size()) * 0.6)
	var leaf_hubs: Array[Vector3i] = []
	
	# Primary leaf cloud always caps the top trunk pinnacle
	leaf_hubs.append(trunk_nodes.back())
	
	var branches_spawned := 0
	for i in range(split_index, trunk_nodes.size() - 1):
		if branches_spawned >= MAX_BRANCHES:
			break
			
		if rng.randf() < BRANCH_CHANCE:
			var branch_origin := trunk_nodes[i]
			
			# Project vectors outwards and upwards
			var angle := rng.randf() * TAU
			var direction_vector := Vector3(cos(angle), rng.randf_range(0.3, 0.8), sin(angle)).normalized()
			var branch_length := rng.randi_range(2, 4)
			
			var branch_pos := Vector3(branch_origin)
			for b in range(branch_length):
				branch_pos += direction_vector
				var b_node := Vector3i(int(round(branch_pos.x)), int(round(branch_pos.y)), int(round(branch_pos.z)))
				VoxelGeometricSculptor.set_block_safe(chunk, b_node, TRUNK_BLOCK)
				
				# Record final coordinate of branch as a foliage cluster hub
				if b == branch_length - 1:
					leaf_hubs.append(b_node)
					
			branches_spawned += 1
			
	# 4. Sculpt Fluffy Leaf Spheres around all endpoints
	for hub in leaf_hubs:
		VoxelGeometricSculptor.sculpt_leaf_sphere(chunk, hub, LEAF_RADIUS, rng)
