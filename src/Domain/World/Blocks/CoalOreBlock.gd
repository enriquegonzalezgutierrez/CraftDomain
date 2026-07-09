# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: CoalOreBlock
# Description: Concrete Domain Definition for the deep Coal Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Coal Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name CoalOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 21 # Equivalent to BlockType.Type.COAL_ORE
	translation_key = "BLOCK_COAL_ORE"
	is_solid = true
	is_transparent = false
	
	# Procedural dark charcoal colors for unshaded fallback rendering
	color_top = Color(0.12, 0.12, 0.14)
	color_side = Color(0.08, 0.08, 0.10)
	color_bottom = Color(0.05, 0.05, 0.06)
	
	# Visual descriptions for Infrastructure PBR compilation
	texture_file_name = "coal_ore.png"
	roughness = 0.85 # Rough stone texture
	metallic = 0.0
	rendering_type = "default"
