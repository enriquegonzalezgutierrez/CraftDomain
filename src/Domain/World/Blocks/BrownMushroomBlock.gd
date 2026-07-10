# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: BrownMushroomBlock
# Description: Concrete Domain Definition for the Brown Mushroom decoration.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the small Brown Mushroom.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/BrownMushroomBlock.gd
# ==============================================================================
class_name BrownMushroomBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 geometry
	super()
	
	# Domain Properties mapping
	type = 40 # Equivalent to BlockType.Type.BROWN_MUSHROOM
	translation_key = "BLOCK_BROWN_MUSHROOM"
	
	# Physical Properties: Entities must walk through decorations without collision
	is_solid = false
	is_transparent = true # Essential for alpha-scissor clipping in shaders
	
	# OCP/SOLID Compliance: Fragile mushroom breaks on 1 hit
	mining_resistance = 1
	
	# Procedural brown-cap and white-stalk colors for unshaded fallback
	color_top = Color(0.52, 0.38, 0.22)
	color_side = Color(0.45, 0.32, 0.18)
	color_bottom = Color(0.95, 0.95, 0.98)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "brown_mushroom.png"
	roughness = 0.95 # Matte organic fibers
	metallic = 0.0
	
	# Foliage rendering type sways the mushroom gently under the wind
	rendering_type = "foliage"
