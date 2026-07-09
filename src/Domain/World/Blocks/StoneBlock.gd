# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: StoneBlock
# Description: Concrete Domain Definition for the standard heavy Stone Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Stone Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Can be safely
#   added or removed from the project without modifying any central codebases.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name StoneBlock
extends BlockDefinition


func _init() -> void:
	# Calls the base constructor which sets up the FullCubeGeometry by default
	super()
	
	# Domain Properties mapping
	type = 1 # Equivalent to BlockType.Type.STONE
	translation_key = "BLOCK_STONE"
	is_solid = true
	is_transparent = false
	
	# Procedural colors for unshaded rendering falls
	color_top = Color(0.55, 0.55, 0.55)
	color_side = Color(0.48, 0.48, 0.48)
	color_bottom = Color(0.42, 0.42, 0.42)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "stone.png"
	roughness = 0.55
	metallic = 0.0
	rendering_type = "default"
