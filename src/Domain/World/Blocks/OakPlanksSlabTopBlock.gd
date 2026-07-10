# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: OakPlanksSlabTopBlock
# Description: Concrete Domain Definition for the Wood Oak Planks Slab (Top half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   procedural coloring, and custom half-height top geometry for the wooden slab.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By injecting 
#   'TopSlabGeometry', the mesher automatically handles the non-cubic shape.
# - Dependency Inversion Principle (DIP): Depends on the IVoxelGeometry 
#   interface rather than hardcoded vertex arrays.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/OakPlanksSlabTopBlock.gd
# ==============================================================================
class_name OakPlanksSlabTopBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 41 # Equivalent to BlockType.Type.OAK_PLANKS_SLAB_TOP
	translation_key = "BLOCK_OAK_PLANKS_SLAB_TOP"
	is_solid = true
	is_transparent = true # Slabs allow adjacent face visibility
	
	# OCP/SOLID Compliance: Refined wood requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural wood-brown colors for unshaded fallback rendering
	color_top = Color(0.85, 0.65, 0.40)
	color_side = Color(0.75, 0.55, 0.30)
	color_bottom = Color(0.65, 0.45, 0.25)
	
	# Visual descriptions for PBR texture mapping (Reuses wood planks texture!)
	texture_file_name = "wood.png"
	roughness = 0.75
	metallic = 0.0
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height top strategy
	geometry = TopSlabGeometry.new()
