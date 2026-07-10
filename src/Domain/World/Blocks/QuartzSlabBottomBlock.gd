# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: QuartzSlabBottomBlock
# Description: Concrete Domain Definition for the Quartz Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the quartz slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/QuartzSlabBottomBlock.gd
# ==============================================================================
class_name QuartzSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 70 # Equivalent to BlockType.Type.QUARTZ_SLAB_BOTTOM
	translation_key = "BLOCK_QUARTZ_SLAB_BOTTOM"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Thinner slab requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural pure white marble colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 1.0)
	color_side = Color(0.92, 0.92, 0.95)
	color_bottom = Color(0.85, 0.85, 0.88)
	
	# Visual descriptions for PBR texture mapping (Reuses quartz block texture!)
	texture_file_name = "quartz_block.png"
	roughness = 0.35 # Semi-smooth polished marble finish
	metallic = 0.05
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height bottom strategy
	geometry = BottomSlabGeometry.new()
