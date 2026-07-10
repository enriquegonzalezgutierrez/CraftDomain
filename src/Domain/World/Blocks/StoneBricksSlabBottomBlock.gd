# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: IceSlabBottomBlock
# Description: Concrete Domain Definition for the Ice Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the ice slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/IceSlabBottomBlock.gd
# ==============================================================================
class_name IceSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 60 # Equivalent to BlockType.Type.ICE_SLAB_BOTTOM
	translation_key = "BLOCK_ICE_SLAB_BOTTOM"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Thinner ice slab requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural translucent blue colors for unshaded fallback rendering
	color_top = Color(0.62, 0.88, 0.95, 0.75)
	color_side = Color(0.55, 0.82, 0.9, 0.75)
	color_bottom = Color(0.48, 0.75, 0.85, 0.75)
	
	# Visual descriptions for PBR texture mapping (Reuses blue ice texture!)
	texture_file_name = "ice.png"
	roughness = 0.1 # Highly glossy, slippery ice
	metallic = 0.2
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height bottom strategy
	geometry = BottomSlabGeometry.new()
