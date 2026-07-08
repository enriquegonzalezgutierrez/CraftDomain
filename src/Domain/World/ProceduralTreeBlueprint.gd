# ==============================================================================
# Project: CraftDomain
# Description: Master Procedural Generation Strategy for all biological structures.
#              Replaces static JSON coordinate templates with fast, memory-safe,
#              and infinitely varied math-driven growth algorithms.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively encapsulates vector-math,
#   branching bifurcation, and spherical leaf cloud sculpting.
# - Open-Closed Principle (OCP): Highly parameterized. New biological species
#   can be added by appending configuration profiles to the 'Species' registry
#   without changing the underlying trigonometric generation algorithms.
# - Liskov Substitution Principle (LSP): Fully satisfies the IStructureBlueprint 
#   domain contract.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/ProceduralTreeBlueprint.gd
# ==============================================================================
class_name ProceduralTreeBlueprint
extends IStructureBlueprint

## Domain Classification for environmental spawning and AI pathing rules
enum RoleType {
	VILLAGER,
	MERCHANT,
	GUARD,
	FARMER,
	MINER,
	DRUID,
	GOLEM
}

# Configurable strategic properties
var _species_id: int
var _trunk_block: BlockType.Type
var _leaves_block: BlockType.Type

# Dynamic dimension parameters
var _min_height: int
var _max_height: int
var _branch_chance: float
var _max_branches: int
var _leaf_radius: float
var _trunk_lean_factor: float


func _init(species_type: ProceduralTreeBlueprint.Species) -> void:
	_species_id = species_type as int
	_compile_species_profile(species_type)


## Concrete Implementation: Returns the strategic ID representing this blueprint instance
func get_structure_id() -> int:
	return _species_id


## Concrete Implementation: Drives the deterministic, seeded mathematical growth pipeline
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Compute a deterministic seed based on coordinate hashes to ensure stable reloads
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Compute dynamic dimensions for this specific tree instance
	var final_height := rng.randi_range(_min_height, _max_height)
	
	# Execute specialized growth pipeline depending on the biological profile
	match _species_id:
		ProceduralTreeBlueprint.Species.GIANT_MUSHROOM, ProceduralTreeBlueprint.Species.UNDERWORLD_FUNGUS:
			_grow_mushroom_structure(chunk, start_x, start_z, ground_y, final_height, rng)
		ProceduralTreeBlueprint.Species.ROSE_BUSH, ProceduralTreeBlueprint.Species.DEAD_SHRUB:
			_grow_bush_structure(chunk, start_x, start_z, ground_y, final_height, rng)
		ProceduralTreeBlueprint.Species.REDWOOD:
			_grow_radial_conifer_structure(chunk, start_x, start_z, ground_y, final_height, rng)
		_:
			# Standard Branching Deciduous (Oak, Sakura, Birch)
			_grow_deciduous_branching_structure(chunk, start_x, start_z, ground_y, final_height, rng)


# ==============================================================================
# SPECIES MOLECULAR DATA REGISTRY (OCP Compliant)
# ==============================================================================

func _compile_species_profile(species_type: ProceduralTreeBlueprint.Species) -> void:
	match species_type:
		ProceduralTreeBlueprint.Species.OAK:
			_trunk_block = BlockType.Type.WOOD
			_leaves_block = BlockType.Type.LEAVES
			_min_height = 5
			_max_height = 8
			_branch_chance = 0.45
			_max_branches = 3
			_leaf_radius = 2.8
			_trunk_lean_factor = 0.35
			
		ProceduralTreeBlueprint.Species.BIRCH:
			_trunk_block = BlockType.Type.BIRCH_LOG
			_leaves_block = BlockType.Type.LEAVES
			_min_height = 6
			_max_height = 9
			_branch_chance = 0.25
			_max_branches = 2
			_leaf_radius = 2.2
			_trunk_lean_factor = 0.15
			
		ProceduralTreeBlueprint.Species.SAKURA:
			_trunk_block = BlockType.Type.WOOD
			_leaves_block = BlockType.Type.NEON_MAGENTA # Pink Sakura leaf proxy
			_min_height = 5
			_max_height = 7
			_branch_chance = 0.55
			_max_branches = 4
			_leaf_radius = 3.0
			_trunk_lean_factor = 0.45
			
		ProceduralTreeBlueprint.Species.REDWOOD:
			_trunk_block = BlockType.Type.WOOD
			_leaves_block = BlockType.Type.LEAVES
			_min_height = 10
			_max_height = 14
			_branch_chance = 0.85 # Radial tiered branch frequency
			_max_branches = 12
			_leaf_radius = 3.2
			_trunk_lean_factor = 0.05 
			
		ProceduralTreeBlueprint.Species.GIANT_MUSHROOM:
			_trunk_block = BlockType.Type.SNOW # Clean matte-white stem
			_leaves_block = BlockType.Type.RED_SAND # Bright red dotted cap
			_min_height = 4
			_max_height = 6
			_branch_chance = 0.0
			_max_branches = 0
			_leaf_radius = 2.5
			_trunk_lean_factor = 0.0
			
		ProceduralTreeBlueprint.Species.UNDERWORLD_FUNGUS:
			_trunk_block = BlockType.Type.STONE # Rusted dark stalk
			_leaves_block = BlockType.Type.NEON_CYAN # Glowing blue conduit gills
			_min_height = 3
			_max_height = 5
			_branch_chance = 0.0
			_max_branches = 0
			_leaf_radius = 2.0
			_trunk_lean_factor = 0.0
			
		ProceduralTreeBlueprint.Species.ROSE_BUSH:
			_trunk_block = BlockType.Type.LEAVES
			_leaves_block = BlockType.Type.RED_SAND # Red flower blossoms
			_min_height = 2
			_max_height = 3
			_branch_chance = 0.0
			_max_branches = 0
			_leaf_radius = 1.2
			_trunk_lean_factor = 0.0
			
		ProceduralTreeBlueprint.Species.DEAD_SHRUB:
			_trunk_block = BlockType.Type.WOOD
			_leaves_block = BlockType.Type.AIR # Leafless
			_min_height = 1
			_max_height = 2
			_branch_chance = 0.0
			_max_branches = 0
			_leaf_radius = 0.0
			_trunk_lean_factor = 0.5


# ==============================================================================
# PROCEDURAL GROWTH ENGINES
# ==============================================================================

## Growth Engine A: Deciduous trees with organic leaning trunks, bifurcation, and leaf clouds
func _grow_deciduous_branching_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int, height: int, rng: RandomNumberGenerator) -> void:
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# 1. Grow Leaning Trunk
	for h in range(height):
		current_pos.y += 1.0
		if h > 2 and rng.randf() < _trunk_lean_factor:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		_set_block_safe(chunk, node, _trunk_block)
		
	# 2. Branching Bifurcation (Occurs in the upper 40% height segment of the trunk)
	var split_index := int(float(trunk_nodes.size()) * 0.6)
	var leaf_hubs: Array[Vector3i] = []
	
	# Always place a main leaf dome at the absolute pinnacle of the trunk
	leaf_hubs.append(trunk_nodes.back())
	
	var branches_spawned := 0
	for i in range(split_index, trunk_nodes.size() - 1):
		if branches_spawned >= _max_branches:
			break
			
		if rng.randf() < _branch_chance:
			var branch_origin := trunk_nodes[i]
			
			# Trigonometric vector pointing outwards and upwards
			var angle := rng.randf() * TAU
			var dir := Vector3(cos(angle), rng.randf_range(0.3, 0.8), sin(angle)).normalized()
			var length := rng.randi_range(2, 4)
			
			var branch_pos := Vector3(branch_origin)
			for b in range(length):
				branch_pos += dir
				var b_node := Vector3i(int(round(branch_pos.x)), int(round(branch_pos.y)), int(round(branch_pos.z)))
				_set_block_safe(chunk, b_node, _trunk_block)
				
				# Store branch end coordinate as leaf cloud hub
				if b == length - 1:
					leaf_hubs.append(b_node)
					
			branches_spawned += 1
			
	# 3. Sculpt Spherical Leaf Clouds around all registered hubs
	for hub in leaf_hubs:
		_sculpt_leaf_sphere(chunk, hub, _leaf_radius, rng)


## Growth Engine B: Radial layered conifers (Spruce/Redwood style)
func _grow_radial_conifer_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int, height: int, rng: RandomNumberGenerator) -> void:
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# 1. Grow towering straight trunk
	for h in range(height):
		current_pos.y += 1.0
		# Extremely narrow trunk-leaning to keep conifers upright
		if h > 5 and rng.randf() < _trunk_lean_factor:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		_set_block_safe(chunk, node, _trunk_block)
		
	# 2. Grow radially segmented needle skirts along the upper 70% of the tree height
	var canopy_start_y := int(float(height) * 0.3)
	
	for i in range(canopy_start_y, height):
		var node := trunk_nodes[i]
		
		# Linear interpolation: Canopy skirt radius tapers towards the top spire
		var t := float(i - canopy_start_y) / float(height - canopy_start_y)
		var current_skirt_radius := lerp(_leaf_radius, 1.0, t)
		
		# Create radial layered foliage rings
		_sculpt_conifer_flat_ring(chunk, node, current_skirt_radius)
		
	# 3. Mount high-density pinnacle needle
	var tip := trunk_nodes.back()
	_set_block_safe(chunk, tip + Vector3i(0, 1, 0), _leaves_block)
	_set_block_safe(chunk, tip + Vector3i(0, 2, 0), _leaves_block)


## Growth Engine C: Thick-stemmed, wide-cap mushrooms
func _grow_mushroom_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int, height: int, _rng: RandomNumberGenerator) -> void:
	# 1. Grow thick white stalk
	for y in range(1, height + 1):
		_set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), _trunk_block)
		
	# 2. Grow massive flat umbrella cap with dynamic radial bounds
	var cap_y := ground_y + height + 1
	var cap_radius := int(_leaf_radius)
	
	for lx in range(-cap_radius, cap_radius + 1):
		for lz in range(-cap_radius, cap_radius + 1):
			var dist_sq := lx * lx + lz * lz
			
			# Form a perfect organic circle
			if dist_sq <= cap_radius * cap_radius:
				var px := start_x + lx
				var pz := start_z + lz
				
				_set_block_safe(chunk, Vector3i(px, cap_y, pz), _leaves_block)
				# Double layer thickness towards center for volume depth
				if dist_sq < (cap_radius - 1) * (cap_radius - 1):
					_set_block_safe(chunk, Vector3i(px, cap_y + 1, pz), _leaves_block)
					
					# Special: Dot the mushrooms with white caps
					if (lx + lz) % 2 == 0:
						_set_block_safe(chunk, Vector3i(px, cap_y + 1, pz), _trunk_block)


## Growth Engine D: Compact bushes and shrubs
func _grow_bush_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int, height: int, rng: RandomNumberGenerator) -> void:
	# 1. Base stalk
	for y in range(1, height + 1):
		_set_block_safe(chunk, Vector3i(start_x, ground_y + y, start_z), _trunk_block)
		
	# 2. Clustered tiny dome
	if _leaves_block != BlockType.Type.AIR:
		var hub := Vector3i(start_x, ground_y + height, start_z)
		_sculpt_leaf_sphere(chunk, hub, _leaf_radius, rng)
	else:
		# Leafless dead shrub branches
		_set_block_safe(chunk, Vector3i(start_x + 1, ground_y + 1, start_z), _trunk_block)
		_set_block_safe(chunk, Vector3i(start_x - 1, ground_y + 1, start_z + 1), _trunk_block)


# ==============================================================================
# GEOMETRIC VECTOR TOOLS (SRP Helpers)
# ==============================================================================

## Mathematically sculpts an organic, overlapping sphere of leaves around a target hub
static func _sculpt_leaf_sphere(chunk: Chunk, hub: Vector3i, radius: float, rng: RandomNumberGenerator) -> void:
	var r_int := int(ceil(radius))
	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			for z in range(-r_int, r_int + 1):
				var dist_sq := float(x * x + y * y + z * z)
				var target_radius_sq := radius * radius
				
				# Noise perturbation to generate uneven, organic outlines
				if rng.randf() < 0.25:
					target_radius_sq *= 0.85
					
				if dist_sq <= target_radius_sq:
					var target_pos := hub + Vector3i(x, y, z)
					
					var existing := chunk.get_block(target_pos.x, target_pos.y, target_pos.z)
					if existing != BlockType.Type.WOOD and existing != BlockType.Type.BIRCH_LOG:
						_set_block_safe(chunk, target_pos, BlockType.Type.LEAVES)


## Creates flat, circular needle plates for conifer segmented skirts
static func _sculpt_conifer_flat_ring(chunk: Chunk, center_node: Vector3i, radius: float) -> void:
	var r_int := int(ceil(radius))
	for x in range(-r_int, r_int + 1):
		for z in range(-r_int, r_int + 1):
			var dist_sq := float(x * x + z * z)
			if dist_sq <= radius * radius:
				var target_pos := center_node + Vector3i(x, 0, z)
				
				var existing := chunk.get_block(target_pos.x, target_pos.y, target_pos.z)
				if existing != BlockType.Type.WOOD:
					_set_block_safe(chunk, target_pos, BlockType.Type.LEAVES)


## Safeguard method ensuring writing only occurs inside valid chunk boundaries
static func _set_block_safe(chunk: Chunk, pos: Vector3i, type: BlockType.Type) -> void:
	if chunk.is_within_bounds(pos.x, pos.y, pos.z):
		chunk.set_block(pos.x, pos.y, pos.z, type)


# ==============================================================================
# SPECIES ENUM HOLDER (Bypasses old separate classes)
# ==============================================================================
enum Species {
	OAK = 0,
	BIRCH = 1,
	REDWOOD = 2,
	SAKURA = 3,
	GIANT_MUSHROOM = 4,
	UNDERWORLD_FUNGUS = 5,
	ROSE_BUSH = 6,
	DEAD_SHRUB = 7
}
