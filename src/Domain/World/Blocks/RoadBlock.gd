# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RoadBlock
# Description: Concrete Domain Definition for the asphalt Paved Road.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Road Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading from the /Blocks/ directory on startup.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name RoadBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 25 # Equivalent to BlockType.Type.ROAD
	translation_key = "BLOCK_ROAD"
	is_solid = true
	is_transparent = false
	
	# Procedural dark asphalt colors for unshaded fallback rendering
	color_top = Color(0.24, 0.24, 0.28)
	color_side = Color(0.18, 0.18, 0.22)
	color_bottom = Color(0.24, 0.24, 0.28)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "road.png"
	roughness = 0.55 # Semi-smooth asphalt finish
	metallic = 0.0
	rendering_type = "default"
