# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/SugarCaneBlock.gd
# Description: Concrete Domain Definition for the segmented Sugar Cane stalk.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the Sugar Cane block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 105
#   (SUGAR_CANE) to consume "sugar_cane.png" from the assets database.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry
#   to render intersecting diagonal quads instead of full solid cubes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SugarCaneBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 105 # OCP Assigned ID for Sugar Cane
	translation_key = "BLOCK_SUGAR_CANE"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	is_spawnable_soil = false
	
	# Procedural bright-green colors for unshaded fallback rendering
	color_top = Color(0.45, 0.85, 0.15)
	color_side = Color(0.35, 0.75, 0.10)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "sugar_cane.png"
	roughness = 0.95 # Matte plant stalks
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
