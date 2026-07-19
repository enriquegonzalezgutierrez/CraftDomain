# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/TulipPinkBlock.gd
# Description: Concrete Domain Definition for the pink wild Tulip flower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Pink Tulip block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 108
#   (TULIP_PINK) to consume "tulip_pink.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TulipPinkBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 108 # OCP Assigned ID for Pink Tulip
	translation_key = "BLOCK_TULIP_PINK"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	
	# Procedural pastel-pink colors for unshaded fallback rendering
	color_top = Color(0.95, 0.45, 0.72)
	color_side = Color(0.85, 0.35, 0.62)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "tulip_pink.png"
	roughness = 0.95 # Matte flower petals
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
