# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/MetalGrateBlock.gd
# Description: Concrete Domain Definition for the industrial Metal Grate block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Metal Grate.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 94
#   (METAL_GRATE) to consume "metal_grate.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MetalGrateBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 94 # OCP Assigned ID for Metal Grate
	translation_key = "BLOCK_METAL_GRATE"
	is_solid = true
	is_transparent = true # For alpha scissor holes in the metal grate mesh
	
	# Reinforced iron grates require 4 impacts to break
	mining_resistance = 4
	
	# Procedural metallic grey colors for unshaded fallback rendering
	color_top = Color(0.55, 0.55, 0.58)
	color_side = Color(0.48, 0.48, 0.50)
	color_bottom = Color(0.38, 0.38, 0.40)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "metal_grate.png"
	roughness = 0.45 # Semi-smooth industrial steel
	metallic = 0.90 # Strong metallic reflection
	rendering_type = "default"
