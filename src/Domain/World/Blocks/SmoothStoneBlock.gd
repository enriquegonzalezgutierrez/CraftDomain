# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SmoothStoneBlock
# Description: Concrete Domain Definition for the refined Smooth Stone block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Smooth Stone.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SmoothStoneBlock.gd
# ==============================================================================
class_name SmoothStoneBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 50 # Equivalent to BlockType.Type.SMOOTH_STONE
	translation_key = "BLOCK_SMOOTH_STONE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Polished architecture stone requires 3 hits to break
	mining_resistance = 3
	
	# Procedural polished grey concrete colors for unshaded fallback
	color_top = Color(0.60, 0.60, 0.62)
	color_side = Color(0.55, 0.55, 0.58)
	color_bottom = Color(0.48, 0.48, 0.50)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "smooth_stone.png"
	roughness = 0.55 # Polished semi-matte concrete finish
	metallic = 0.0
	rendering_type = "default"
