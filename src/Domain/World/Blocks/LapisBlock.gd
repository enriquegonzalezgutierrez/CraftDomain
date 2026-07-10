# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: LapisBlock
# Description: Concrete Domain Definition for the refined solid Lapis Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Lapis Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/LapisBlock.gd
# ==============================================================================
class_name LapisBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 73 # Equivalent to BlockType.Type.LAPIS_BLOCK
	translation_key = "BLOCK_LAPIS_BLOCK"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Solid precious block requires 4 hits to break
	mining_resistance = 4
	
	# Procedural deep blue and gold-speckle colors for unshaded fallback
	color_top = Color(0.15, 0.35, 0.72)
	color_side = Color(0.10, 0.28, 0.62)
	color_bottom = Color(0.08, 0.22, 0.52)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "lapis_block.png"
	roughness = 0.55 # Polished stone finish
	metallic = 0.15 # Pyrite golden glitter reflections
	rendering_type = "default"
