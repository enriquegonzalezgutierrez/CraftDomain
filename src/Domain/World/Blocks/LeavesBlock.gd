# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: LeavesBlock
# Description: Concrete Domain Definition for the organic Shrubbery Leaves.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and wind-sway configurations for foliage.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Uses the 'foliage' 
#   rendering type to polymorphically trigger wind shaders without hardcoding 
#   logic in the Chunk mesher.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name LeavesBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 5 # Equivalent to BlockType.Type.LEAVES
	translation_key = "BLOCK_LEAVES"
	is_solid = true
	is_transparent = true # Allows alpha clipping/scissor for pixel-art leaves
	
	# Procedural organic green colors for unshaded fallback rendering
	color_top = Color(0.25, 0.65, 0.18)
	color_side = Color(0.20, 0.55, 0.15)
	color_bottom = Color(0.15, 0.45, 0.12)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "leaves.png"
	roughness = 0.85
	
	# ==========================================================================
	# OCP RENDERING FLAG:
	# Setting this to "foliage" tells the ChunkNode to apply the 
	# wind-sway vertex shader automatically.
	# ==========================================================================
	rendering_type = "foliage"
