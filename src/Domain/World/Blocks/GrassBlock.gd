# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GrassBlock
# Description: Concrete Domain Definition for the vibrant Grass Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Grass Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Overrides 
#   its local spawn variables within the constructor.
# ==============================================================================
class_name GrassBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 3 # Equivalent to BlockType.Type.GRASS
	translation_key = "BLOCK_GRASS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Mobs can spawn on grassy plains
	is_spawnable_soil = true
	
	# ==========================================================================
	# PROCEDURAL COLOR PALETTE:
	# Symmetrical colors for unshaded fallback: vibrant green on top 
	# with loose organic soil on sides and bottom faces.
	# ==========================================================================
	color_top = Color(0.42, 0.78, 0.25)
	color_side = Color(0.48, 0.32, 0.20)
	color_bottom = Color(0.42, 0.28, 0.18)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "grass_top.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
