# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: ChiseledStoneBricksBlock
# Description: Concrete Domain Definition for the decorative Chiseled Stone Bricks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Chiseled Stone Bricks.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/ChiseledStoneBricksBlock.gd
# ==============================================================================
class_name ChiseledStoneBricksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 57 # Equivalent to BlockType.Type.CHISELED_STONE_BRICKS
	translation_key = "BLOCK_CHISELED_STONE_BRICKS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard chiseled ancient stone requires 3 hits to break
	mining_resistance = 3
	
	# Procedural slate-grey castle colors for unshaded fallback
	color_top = Color(0.50, 0.50, 0.52)
	color_side = Color(0.45, 0.45, 0.48)
	color_bottom = Color(0.38, 0.38, 0.40)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "chiseled_stone_bricks.png"
	roughness = 0.85 # Matte masonry finish
	metallic = 0.0
	rendering_type = "default"
