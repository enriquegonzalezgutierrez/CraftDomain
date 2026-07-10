# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SmoothStoneSlabTopBlock
# Description: Concrete Domain Definition for the Smooth Stone Slab (Top half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height top geometry for the smooth stone slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'TopSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SmoothStoneSlabTopBlock.gd
# ==============================================================================
class_name SmoothStoneSlabTopBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 75 # Equivalent to BlockType.Type.SMOOTH_STONE_SLAB_TOP
	translation_key = "BLOCK_SMOOTH_STONE_SLAB_TOP"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Thinner slab requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural polished grey concrete colors for unshaded fallback
	color_top = Color(0.60, 0.60, 0.62)
	color_side = Color(0.55, 0.55, 0.58)
	color_bottom = Color(0.48, 0.48, 0.50)
	
	# Visual descriptions for PBR texture mapping (Reuses smooth stone texture!)
	texture_file_name = "smooth_stone.png"
	roughness = 0.55 # Polished semi-matte concrete finish
	metallic = 0.0
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height top strategy
	geometry = TopSlabGeometry.new()
