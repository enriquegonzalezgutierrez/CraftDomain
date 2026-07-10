# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RedMushroomBlock
# Description: Concrete Domain Definition for the Red Mushroom decoration.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the small Red Mushroom.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/RedMushroomBlock.gd
# ==============================================================================
class_name RedMushroomBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 geometry
	super()
	
	# Domain Properties mapping
	type = 35 # Equivalent to BlockType.Type.RED_MUSHROOM
	translation_key = "BLOCK_RED_MUSHROOM"
	
	# Physical Properties: Entities must walk through decorations without collision
	is_solid = false
	is_transparent = true # Essential for alpha-scissor clipping in shaders
	
	# OCP/SOLID Compliance: Fragile mushroom breaks on 1 hit
	mining_resistance = 1
	
	# Procedural red-cap and white-stalk colors for unshaded fallback
	color_top = Color(0.92, 0.15, 0.15)
	color_side = Color(0.85, 0.12, 0.12)
	color_bottom = Color(0.95, 0.95, 0.98)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "red_mushroom.png"
	roughness = 0.95 # Matte organic fibers
	metallic = 0.0
	
	# Foliage rendering type sways the mushroom gently under the wind
	rendering_type = "foliage"
