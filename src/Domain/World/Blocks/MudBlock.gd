# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: MudBlock
# Description: Concrete Domain Definition for the dark rotting swamp Mud.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Mud Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading from the /Blocks/ directory.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name MudBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 11 # Equivalent to BlockType.Type.MUD
	translation_key = "BLOCK_MUD"
	is_solid = true
	is_transparent = false
	
	# Procedural dark-brown colors for unshaded fallback rendering
	color_top = Color(0.32, 0.25, 0.18)
	color_side = Color(0.28, 0.22, 0.15)
	color_bottom = Color(0.22, 0.18, 0.12)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "mud.png"
	roughness = 0.9 # High matte finish for a viscous organic look
	metallic = 0.0
	rendering_type = "default"
