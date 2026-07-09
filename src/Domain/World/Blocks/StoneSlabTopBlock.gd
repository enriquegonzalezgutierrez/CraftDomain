# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: StoneSlabTopBlock
# Description: Concrete Domain Definition for the Stone Slab (Top half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height top geometry for the slab.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Supports 
#   dynamic independent loading from the /Blocks/ directory.
# - Liskov Substitution Principle (LSP): Fully interchangeable with any 
#   standard block definition while providing specialized geometric data.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name StoneSlabTopBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 27 # Equivalent to BlockType.Type.STONE_SLAB_TOP
	translation_key = "BLOCK_STONE_SLAB_TOP"
	is_solid = true
	
	# OPAQUE CULLING: Marked as transparent to prevent occlusion of the 
	# bottom half of adjacent blocks.
	is_transparent = true 
	
	# Procedural stone-grey colors for unshaded fallback rendering
	color_top = Color(0.55, 0.55, 0.55)
	color_side = Color(0.48, 0.48, 0.48)
	color_bottom = Color(0.42, 0.42, 0.42)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "stone.png"
	roughness = 0.55
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# CUSTOM GEOMETRY STRATEGY:
	# Injects the upper half-height slab strategy.
	# ==========================================================================
	geometry = TopSlabGeometry.new()
