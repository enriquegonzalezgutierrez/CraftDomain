# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: StoneBricksBlock
# Description: Concrete Domain Definition for the elegant Stone Bricks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Stone Bricks.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/StoneBricksBlock.gd
# ==============================================================================
class_name StoneBricksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 53 # Equivalent to BlockType.Type.STONE_BRICKS
	translation_key = "BLOCK_STONE_BRICKS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard refined castle masonry requires 3 hits to break
	mining_resistance = 3
	
	# Procedural slate-grey castle colors for unshaded fallback
	color_top = Color(0.50, 0.50, 0.52)
	color_side = Color(0.45, 0.45, 0.48)
	color_bottom = Color(0.38, 0.38, 0.40)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "stone_bricks.png"
	roughness = 0.85 # Elegant semi-matte finish
	metallic = 0.0
	rendering_type = "default"
