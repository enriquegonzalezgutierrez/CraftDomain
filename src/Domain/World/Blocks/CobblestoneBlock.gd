# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: CobblestoneBlock
# Description: Concrete Domain Definition for the standard Cobblestone.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Cobblestone.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/CobblestoneBlock.gd
# ==============================================================================
class_name CobblestoneBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 47 # Equivalent to BlockType.Type.COBBLESTONE
	translation_key = "BLOCK_COBBLESTONE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard fractured stone requires 3 hits to break
	mining_resistance = 3
	
	# Procedural stone-grey colors for unshaded fallback rendering
	color_top = Color(0.48, 0.48, 0.48)
	color_side = Color(0.42, 0.42, 0.42)
	color_bottom = Color(0.38, 0.38, 0.38)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "cobblestone.png"
	roughness = 0.95 # Rough fractured stone masonry
	metallic = 0.0
	rendering_type = "default"
