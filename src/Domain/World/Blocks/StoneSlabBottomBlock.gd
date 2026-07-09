# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: StoneSlabBottomBlock
# Description: Concrete Domain Definition for the Stone Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name StoneSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 26 # Equivalent to BlockType.Type.STONE_SLAB_BOTTOM
	translation_key = "BLOCK_STONE_SLAB_BOTTOM"
	is_solid = true
	
	# OPAQUE CULLING: Slabs are marked as transparent because they do not 
	# completely fill the voxel volume, allowing neighboring faces to remain visible.
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
	# Overwrites the default FullCubeGeometry with the half-height 
	# bottom-aligned slab strategy.
	# ==========================================================================
	geometry = BottomSlabGeometry.new()
