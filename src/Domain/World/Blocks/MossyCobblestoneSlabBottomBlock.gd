# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: MossyCobblestoneSlabBottomBlock
# Description: Concrete Domain Definition for the Mossy Cobblestone Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the mossy slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/MossyCobblestoneSlabBottomBlock.gd
# ==============================================================================
class_name MossyCobblestoneSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 48 # Equivalent to BlockType.Type.MOSSY_COBBLESTONE_SLAB_BOTTOM
	translation_key = "BLOCK_MOSSY_COBBLESTONE_SLAB_BOTTOM"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Thinner slab requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural dark stone-grey and mossy colors for unshaded fallback
	color_top = Color(0.35, 0.48, 0.25)
	color_side = Color(0.28, 0.38, 0.18)
	color_bottom = Color(0.22, 0.28, 0.12)
	
	# Visual descriptions for PBR texture mapping (Reuses mossy cobblestone texture!)
	texture_file_name = "mossy_cobblestone.png"
	roughness = 0.9 # Rough matte stone and moss
	metallic = 0.0
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height bottom strategy
	geometry = BottomSlabGeometry.new()
