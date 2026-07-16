# ==============================================================================
# Pathfile: res://src/Domain/World/RedwoodTreeBlueprint.gd
# Description: Concrete Structure Blueprint implementing the 3D procedural growth 
#              algorithm for a towering, radial-skirted conifer Redwood Tree.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the growth ratios, 
#   height parameters, and radial layered foliage specific to the Redwood species.
# - Open-Closed Principle (OCP): Inherits from IStructureBlueprint. Integrated 
#   Type-safe BlockType.Type.REDWOOD_LOG enum member to permanently silence warnings.
# - Dependency Inversion Principle (DIP): Delegates heavy geometry drawing to 
#   the decoupled static utility class 'ProceduralTools'.
# Author: Enrique González Gutiérrez 
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RedwoodTreeBlueprint
extends IStructureBlueprint

# Redwood Biological Constants
const TRUNK_BLOCK := BlockType.Type.REDWOOD_LOG # INTEGRATED: Type-safe RedwoodLogBlock enum member
const LEAVES_BLOCK := BlockType.Type.LEAVES

const MIN_HEIGHT: int = 10
const MAX_HEIGHT: int = 14
const LEAN_FACTOR: float = 0.05 # Redwoods stand almost perfectly upright
const MAX_FOLIAGE_RADIUS: float = 3.2


## Concrete Implementation: Returns the unique structure ID for the Redwood Tree (ID 2)
func get_structure_id() -> int:
	return 2


## Concrete Implementation: Grows a towering straight redwood conifer with radial layered rings and top needle
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Seed RNG deterministically based on coordinates to guarantee reload stability
	var coordinate_hash := int(abs(start_x * 73856093 ^ start_z * 19349663))
	var rng := RandomNumberGenerator.new()
	rng.seed = coordinate_hash
	
	# Determine tall height for this giant instance
	var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
	
	var current_pos := Vector3(float(start_x), float(ground_y), float(start_z))
	var trunk_nodes: Array[Vector3i] = []
	
	# Grow Towering Straight Trunk
	for h in range(height):
		current_pos.y += 1.0
		# Minimal sway allowed for giant conifers to prevent lean distortion
		if h > 5 and rng.randf() < LEAN_FACTOR:
			current_pos.x += float(rng.randi_range(-1, 1))
			current_pos.z += float(rng.randi_range(-1, 1))
			
		var node := Vector3i(int(round(current_pos.x)), int(round(current_pos.y)), int(round(current_pos.z)))
		trunk_nodes.append(node)
		ProceduralTools.set_block_safe(chunk, node, TRUNK_BLOCK)
		
	# Create Conifer Radial Skirts (Occurs along the upper 70% height segment of the trunk)
	var canopy_start_y := int(float(height) * 0.3)
	
	for i in range(canopy_start_y, height):
		var node := trunk_nodes[i]
		
		# Linear interpolation: Canopy skirt radius tapers towards the top spire
		var t := float(i - canopy_start_y) / float(height - canopy_start_y)
		var current_skirt_radius := lerp(MAX_FOLIAGE_RADIUS, 1.0, t)
		
		# Sculpt flat conifer radial leaves plate
		ProceduralTools.sculpt_conifer_flat_ring(chunk, node, current_skirt_radius)
		
	# Mount High-Density Pinnacle Needle on top of the spire
	var tip := trunk_nodes.back()
	ProceduralTools.set_block_safe(chunk, tip + Vector3i(0, 1, 0), LEAVES_BLOCK)
	ProceduralTools.set_block_safe(chunk, tip + Vector3i(0, 2, 0), LEAVES_BLOCK)
