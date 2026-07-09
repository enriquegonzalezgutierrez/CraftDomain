# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RedSandBlock
# Description: Concrete Domain Definition for the Terracotta Red Sand.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Red Sand Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading without central registry modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name RedSandBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 8 # Equivalent to BlockType.Type.RED_SAND
	translation_key = "BLOCK_RED_SAND"
	is_solid = true
	is_transparent = false
	
	# Procedural terracotta orange colors for unshaded fallback rendering
	color_top = Color(0.88, 0.42, 0.25)
	color_side = Color(0.82, 0.35, 0.20)
	color_bottom = Color(0.75, 0.30, 0.15)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "red_sand.png"
	roughness = 0.88 
	metallic = 0.0
	rendering_type = "default"
