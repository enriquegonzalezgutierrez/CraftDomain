# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: QuartzOreBlock
# Description: Concrete Domain Definition for the deep Quartz Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Quartz Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/QuartzOreBlock.gd
# ==============================================================================
class_name QuartzOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 68 # Equivalent to BlockType.Type.QUARTZ_ORE
	translation_key = "BLOCK_QUARTZ_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Tough volcanic stone requires 4 hits to extract
	mining_resistance = 4
	
	# Procedural netherrack red and white quartz colors for unshaded fallback
	color_top = Color(0.85, 0.85, 0.90)
	color_side = Color(0.65, 0.18, 0.18)
	color_bottom = Color(0.55, 0.12, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "quartz_ore.png"
	roughness = 0.85
	metallic = 0.15 # Shimmering quartz crystal specularity
	rendering_type = "default"
