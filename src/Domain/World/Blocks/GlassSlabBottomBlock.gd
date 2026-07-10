# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GlassSlabBottomBlock
# Description: Concrete Domain Definition for the Glass Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height geometry for the glass slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'BottomSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/GlassSlabBottomBlock.gd
# ==============================================================================
class_name GlassSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 80 # Equivalent to BlockType.Type.GLASS_SLAB_BOTTOM
	translation_key = "BLOCK_GLASS_SLAB_BOTTOM"
	is_solid = true
	is_transparent = true # Essential for alpha-blending and depth sorting
	
	# OCP/SOLID Compliance: Extremely fragile glass slab breaks on 1 single hit!
	mining_resistance = 1
	
	# Procedural translucent blue colors for unshaded fallback rendering
	color_top = Color(0.85, 0.95, 1.0, 0.35)
	color_side = Color(0.80, 0.92, 0.98, 0.35)
	color_bottom = Color(0.75, 0.88, 0.95, 0.35)
	
	# Visual descriptions for PBR texture mapping (Reuses transparent glass texture!)
	texture_file_name = "glass.png"
	roughness = 0.05 # Glossy, reflective glass
	metallic = 0.1
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height bottom strategy
	geometry = BottomSlabGeometry.new()
