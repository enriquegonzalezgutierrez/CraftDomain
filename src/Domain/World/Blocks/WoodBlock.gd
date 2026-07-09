# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: WoodBlock
# Description: Concrete Domain Definition for the solid structural Oak Wood Log.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Wood Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading without central registry modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name WoodBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 4 # Equivalent to BlockType.Type.WOOD
	translation_key = "BLOCK_WOOD"
	is_solid = true
	is_transparent = false
	
	# Procedural wood-brown colors for unshaded fallback rendering
	color_top = Color(0.72, 0.55, 0.35)
	color_side = Color(0.55, 0.42, 0.28)
	color_bottom = Color(0.72, 0.55, 0.35)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "wood.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
