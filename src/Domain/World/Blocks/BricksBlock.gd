# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: BricksBlock
# Description: Concrete Domain Definition for the fortress red Bricks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Brick Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading from the /Blocks/ directory.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name BricksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 22 # Equivalent to BlockType.Type.BRICKS
	translation_key = "BLOCK_BRICKS"
	is_solid = true
	is_transparent = false
	
	# Procedural baked-clay colors for unshaded fallback rendering
	color_top = Color(0.65, 0.28, 0.22)
	color_side = Color(0.58, 0.22, 0.18)
	color_bottom = Color(0.52, 0.18, 0.15)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "bricks.png"
	roughness = 0.8 # Standard rough masonry finish
	metallic = 0.0
	rendering_type = "default"
