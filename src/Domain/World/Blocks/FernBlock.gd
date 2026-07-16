# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/FernBlock.gd
# Description: Concrete Domain Definition for the lush green wild Fern block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Fern block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 104
#   (FERN) to consume "fern.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FernBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 104 # OCP Assigned ID for Fern
	translation_key = "BLOCK_FERN"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	is_spawnable_soil = false
	
	# Procedural lush green forest colors for unshaded fallback rendering
	color_top = Color(0.18, 0.55, 0.15)
	color_side = Color(0.12, 0.45, 0.12)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "fern.png"
	roughness = 0.95 # Matte conifer leaves
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
