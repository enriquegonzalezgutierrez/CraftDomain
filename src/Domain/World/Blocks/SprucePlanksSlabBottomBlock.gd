# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SprucePlanksSlabBottomBlock
# Description: Concrete Domain Definition for the Spruce Planks Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the dark spruce slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SprucePlanksSlabBottomBlock.gd
# ==============================================================================
class_name SprucePlanksSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 65 # Equivalent to BlockType.Type.SPRUCE_PLANKS_SLAB_BOTTOM
	translation_key = "BLOCK_SPRUCE_PLANKS_SLAB_BOTTOM"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Thinner slab requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural dark chocolate-brown wood colors for unshaded fallback
	color_top = Color(0.38, 0.25, 0.12)
	color_side = Color(0.30, 0.18, 0.08)
	color_bottom = Color(0.24, 0.12, 0.05)
	
	# Visual descriptions for PBR texture mapping (Reuses spruce planks texture!)
	texture_file_name = "spruce_planks.png"
	roughness = 0.8
	metallic = 0.0
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height bottom strategy
	geometry = BottomSlabGeometry.new()
