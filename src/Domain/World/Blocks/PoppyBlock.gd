# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: PoppyBlock
# Description: Concrete Domain Definition for the Poppy red flower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the small Poppy.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/PoppyBlock.gd
# ==============================================================================
class_name PoppyBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 geometry
	super()
	
	# Domain Properties mapping
	type = 51 # Equivalent to BlockType.Type.POPPY
	translation_key = "BLOCK_POPPY"
	
	# Physical Properties: Entities must walk through flowers without collision
	is_solid = false
	is_transparent = true # Essential for alpha-scissor clipping in shaders
	
	# OCP/SOLID Compliance: Fragile flower breaks on 1 hit
	mining_resistance = 1
	
	# Procedural scarlet-blossom and green-stalk colors for unshaded fallback
	color_top = Color(0.92, 0.15, 0.15)
	color_side = Color(0.85, 0.12, 0.12)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "poppy.png"
	roughness = 0.95 # Matte organic fibers
	metallic = 0.0
	
	# Foliage rendering type sways the flower gently under the wind
	rendering_type = "foliage"
