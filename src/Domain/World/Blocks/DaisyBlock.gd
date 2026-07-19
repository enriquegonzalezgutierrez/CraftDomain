# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DaisyBlock.gd
# Description: Concrete Domain Definition for the white wild Daisy flower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Daisy flower block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 103
#   (DAISY_FLOWER) to consume "daisy.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DaisyBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 103 # OCP Assigned ID for Daisy Flower
	translation_key = "BLOCK_DAISY"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	
	# Procedural white and golden-yellow colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 0.98)
	color_side = Color(0.95, 0.85, 0.25)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "daisy.png"
	roughness = 0.95 # Matte flower petals
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
