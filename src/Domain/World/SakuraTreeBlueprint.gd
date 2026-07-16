# ==============================================================================
# Pathfile: res://src/Domain/World/SakuraTreeBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for an artistic, wide-branching pink Sakura Tree.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the growth ratios, 
#   height parameters, and branching coordinates specific to the Sakura species.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Integrated 
#   Type-safe BlockType.Type.CHERRY_LOG enum member to permanently silence warnings.
# - Scope Correction (LSP): Renamed loop counters to lx, ly, and lz to prevent 
#   3D parser namespace collisions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SakuraTreeBlueprint
extends IStructureBlueprint

# Sakura Biological Constants
const TRUNK_BLOCK := BlockType.Type.CHERRY_LOG # INTEGRATED: Type-safe CherryLogBlock enum member
const LEAVES_BLOCK := BlockType.Type.NEON_MAGENTA # Glowing pink blossom foliage proxy

const MIN_HEIGHT: int = 5
const MAX_HEIGHT: int = 7
const LEAN_FACTOR: float = 0.45 # Crooked, wide artistic trunk line
const BRANCH_CHANCE: float = 0.55
const MAX_BRANCHES: int = 4
const LEAF_RADIUS: float = 3.0 # Wide fluffy clouds of pink blossoms


## Concrete Implementation: Returns the unique structure ID for the Sakura Tree (ID 10)
func get_structure_id() -> int:
	return 10


## Concrete Implementation: Grows an organic sakura tree with leaning trunk, wide branches, and pink leaf spheres
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Seed RNG deterministically based on coordinates to guarantee reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine height for this specific instance
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# Grow Crooked Organic Trunk
	for h in range(height):
		current_pos.y += 1.0
		# Apply frequent, wider random walk steps to simulate a bent trunk
		if h > 1 and rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		ProceduralTools.set_block_safe(chunk, node, TRUNK_BLOCK)
		
	# Sprout Wide Branches (Bifurcation begins at 50% height)
	var split_index := int(float(trunk_nodes.size()) * 0.5)
	var leaf_hubs: Array[Vector3i] = []
	
	# Primary top leaf hub
	leaf_hubs.append(trunk_nodes.back())
	
	var branches_spawned := 0
	for i in range(split_index, trunk_nodes.size() - 1):
		if branches_spawned >= MAX_BRANCHES:
			break
			
		if rng.randf() < BRANCH_CHANCE:
			var branch_origin := trunk_nodes[i]
			
			# Project wide, low-angle horizontal branch vectors
			var angle := rng.randf() * TAU
			var direction_vector := Vector3(cos(angle), rng.randf_range(0.2, 0.6), sin(angle)).normalized()
			var branch_length := rng.randi_range(3, 5) # Longer, sweeping branches
			
			var branch_pos := Vector3(branch_origin)
			for b in range(branch_length):
				branch_pos += direction_vector
				var b_node := Vector3i(int(round(branch_pos.x)), int(round(branch_pos.y)), int(round(branch_pos.z)))
				ProceduralTools.set_block_safe(chunk, b_node, TRUNK_BLOCK)
				
				# Record endpoints as pink foliage clouds hubs
				if b == branch_length - 1:
					leaf_hubs.append(b_node)
					
			branches_spawned += 1
			
	# Sculpt Massive Fluffy Pink Clouds of leaves
	for hub in leaf_hubs:
		_sculpt_sakura_pink_sphere(chunk, hub, LEAF_RADIUS, rng)


## Private Helper: Sculpt beautiful pink sakura clouds
static func _sculpt_sakura_pink_sphere(chunk: Chunk, hub: Vector3i, radius: float, rng: RandomNumberGenerator) -> void:
	var r_int := int(ceil(radius))
	for lx in range(-r_int, r_int + 1):
		for ly in range(-r_int, r_int + 1):
			for lz in range(-r_int, r_int + 1):
				var dist_sq := float(lx * lx + ly * ly + lz * lz)
				var target_radius_sq := radius * radius
				
				# Add structural noise to make the blossom cloud look irregular
				if rng.randf() < 0.25:
					target_radius_sq *= 0.85
					
				if dist_sq <= target_radius_sq:
					var target_pos := hub + Vector3i(lx, ly, lz)
					
					var existing := chunk.get_block(target_pos.x, target_pos.y, target_pos.z)
					# Do not overwrite solid trunk wood with sakura blossom leaves
					if existing != BlockType.Type.WOOD and existing != BlockType.Type.CHERRY_LOG:
						ProceduralTools.set_block_safe(chunk, target_pos, LEAVES_BLOCK)
