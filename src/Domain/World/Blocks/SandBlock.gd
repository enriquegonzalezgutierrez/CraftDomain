# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SandBlock
# Description: Concrete Domain Definition for the fine granular beach Sand.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Sand Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Overrides 
#   its local drop variables within the constructor to decouple mining drop tables.
# ==============================================================================
class_name SandBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 7 # Equivalent to BlockType.Type.SAND
	translation_key = "BLOCK_SAND"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Sand deposits crumble and drop Dirt Blocks (ID 2)
	drop_item_id = 2
	drop_quantity = 1
	
	# Procedural yellow-sand colors for unshaded fallback rendering
	color_top = Color(0.95, 0.90, 0.65)
	color_side = Color(0.88, 0.82, 0.58)
	color_bottom = Color(0.82, 0.75, 0.52)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "sand.png"
	roughness = 0.88 # High roughness for a granular matte finish
	metallic = 0.0
	rendering_type = "default"
