# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GoldBlock
# Description: Concrete Domain Definition for the refined solid Gold Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Gold Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/GoldBlock.gd
# ==============================================================================
class_name GoldBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 37 # Equivalent to BlockType.Type.GOLD_BLOCK
	translation_key = "BLOCK_GOLD_BLOCK"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Pure solid gold block requires 5 hits to break
	mining_resistance = 5
	
	# Procedural rich golden-yellow colors for unshaded fallback
	color_top = Color(0.95, 0.85, 0.25)
	color_side = Color(0.85, 0.75, 0.15)
	color_bottom = Color(0.75, 0.65, 0.10)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "gold_block.png"
	roughness = 0.25 # Glossy, highly polished finish
	metallic = 0.95 # Rich golden specular reflections
	rendering_type = "default"
