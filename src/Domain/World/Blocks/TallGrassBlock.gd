# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/TallGrassBlock.gd
# Description: Concrete Domain Definition for the organic wild Tall Grass.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Tall Grass block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 85
#   (TALL_GRASS) to consume "tall_grass.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TallGrassBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 85 # OCP Assigned ID for Tall Grass
	translation_key = "BLOCK_TALL_GRASS"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	
	# Procedural bright green colors for unshaded fallback rendering
	color_top = Color(0.42, 0.85, 0.25)
	color_side = Color(0.38, 0.75, 0.20)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "tall_grass.png"
	roughness = 0.95 # Matte plant epidermis
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
