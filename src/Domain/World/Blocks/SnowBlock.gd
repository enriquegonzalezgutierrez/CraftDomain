# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SnowBlock
# Description: Concrete Domain Definition for the fluffy powder Snow.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Snow Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading without central registry modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name SnowBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 9 # Equivalent to BlockType.Type.SNOW
	translation_key = "BLOCK_SNOW"
	is_solid = true
	is_transparent = false
	
	# Procedural pristine white colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 0.98)
	color_side = Color(0.92, 0.94, 0.96)
	color_bottom = Color(0.88, 0.9, 0.92)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "snow.png"
	roughness = 0.9 # High matte finish to simulate light absorption
	metallic = 0.0
	rendering_type = "default"
