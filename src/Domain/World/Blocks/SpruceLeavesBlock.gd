# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SpruceLeavesBlock
# Description: Concrete Domain Definition for the solid dark Spruce Leaves.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and wind-sway configurations for Spruce Leaves.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SpruceLeavesBlock.gd
# ==============================================================================
class_name SpruceLeavesBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 67 # Equivalent to BlockType.Type.SPRUCE_LEAVES
	translation_key = "BLOCK_SPRUCE_LEAVES"
	is_solid = true
	is_transparent = true # Essential for alpha-scissor clipping in shaders
	
	# OCP/SOLID Compliance: Fragile conifer foliage breaks on 1 hit
	mining_resistance = 1
	
	# Procedural deep conifer green colors for unshaded fallback
	color_top = Color(0.12, 0.35, 0.22)
	color_side = Color(0.08, 0.28, 0.18)
	color_bottom = Color(0.05, 0.22, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "spruce_leaves.png"
	roughness = 0.95 # Matte conifer needles
	metallic = 0.0
	
	# Foliage rendering type sways the pine needles gently under the wind
	rendering_type = "foliage"
