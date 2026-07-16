# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DeadBushBlock.gd
# Description: Concrete Domain Definition for the dry Dead Bush desert shrub.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and dry-timber configurations for the Dead Bush block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 82
#   (DEAD_BUSH) to consume "dead_bush.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DeadBushBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 82 # OCP Assigned ID for Dead Bush
	translation_key = "BLOCK_DEAD_BUSH"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	is_spawnable_soil = false
	
	# Procedural dry-wood brown colors for unshaded fallback rendering
	color_top = Color(0.55, 0.42, 0.28)
	color_side = Color(0.48, 0.35, 0.22)
	color_bottom = Color(0.35, 0.22, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "dead_bush.png"
	roughness = 0.95 # Matte dry twigs
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
