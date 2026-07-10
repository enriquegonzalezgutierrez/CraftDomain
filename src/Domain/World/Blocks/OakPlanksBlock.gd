# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: OakPlanksBlock
# Description: Concrete Domain Definition for the refined Oak wood Planks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Oak Planks Block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Configures its 
#   mining resistance locally to restore gameplay balance.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/OakPlanksBlock.gd
# ==============================================================================
class_name OakPlanksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 29 # Equivalent to BlockType.Type.OAK_PLANKS
	translation_key = "BLOCK_OAK_PLANKS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Enforce 2 impacts resistance for refined planks
	mining_resistance = 2
	
	# Procedural polished-wood colors for unshaded fallback rendering
	color_top = Color(0.85, 0.65, 0.40)
	color_side = Color(0.75, 0.55, 0.30)
	color_bottom = Color(0.65, 0.45, 0.25)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "wood.png" # Reuses the wood texture mapping
	roughness = 0.75
	metallic = 0.0
	rendering_type = "default"
