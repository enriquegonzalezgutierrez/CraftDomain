# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: StoneSlabBottomBlock
# Description: Concrete Voxel Geometry strategy representing a bottom slab block 
#              occupying the lower half of a voxel coordinate.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Stone Slab (Bottom).
# - Open-Closed Principle (OCP): Extends BlockDefinition. Overrides 
#   its local drop variables within the constructor to decouple mining drop tables.
# ==============================================================================
class_name StoneSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	# Domain Properties mapping
	type = 26 # Equivalent to BlockType.Type.STONE_SLAB_BOTTOM
	translation_key = "BLOCK_STONE_SLAB_BOTTOM"
	is_solid = true
	
	# Opaque Culling: Slabs allow adjacent face visibility
	is_transparent = true 
	
	# OCP/SOLID Compliance: Bottom stone slabs drop the Stone Slab Item (ID 26)
	drop_item_id = 26
	drop_quantity = 1
	
	# OCP/SOLID Compliance: Enforce 2 impacts resistance for half-height stone slabs
	mining_resistance = 2
	
	# Procedural stone-grey colors for unshaded fallback rendering
	color_top = Color(0.55, 0.55, 0.55)
	color_side = Color(0.48, 0.48, 0.48)
	color_bottom = Color(0.42, 0.42, 0.42)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "stone.png"
	roughness = 0.55
	metallic = 0.0
	rendering_type = "default"
	
	# Overwrites the default FullCubeGeometry with the half-height 
	# bottom-aligned slab strategy.
	geometry = BottomSlabGeometry.new()
