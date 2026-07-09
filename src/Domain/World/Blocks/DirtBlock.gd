# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: DirtBlock
# Description: Concrete Domain Definition for the loose organic Dirt Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Dirt Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Can be safely
#   added or removed from the project without modifying any central codebases.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name DirtBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 2 # Equivalent to BlockType.Type.DIRT
	translation_key = "BLOCK_DIRT"
	is_solid = true
	is_transparent = false
	
	# Procedural organic brown colors for unshaded fallback rendering
	color_top = Color(0.55, 0.38, 0.25)
	color_side = Color(0.48, 0.32, 0.20)
	color_bottom = Color(0.42, 0.28, 0.18)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "dirt.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
