# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/CornflowerBlock.gd
# Description: Concrete Domain Definition for the deep royal-blue wild Cornflower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Cornflower block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 102
#   (CORNFLOWER) to consume "cornflower.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CornflowerBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 102 # OCP Assigned ID for Cornflower
	translation_key = "BLOCK_CORNFLOWER"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	
	# Procedural deep royal-blue colors for unshaded fallback rendering
	color_top = Color(0.12, 0.45, 0.95)
	color_side = Color(0.08, 0.35, 0.85)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "cornflower.png"
	roughness = 0.95 # Matte flower petals
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
