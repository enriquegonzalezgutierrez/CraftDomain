# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/StoneBricksSlabBottomBlock.gd
# Description: Concrete Domain Definition for the Stone Bricks Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and custom half-height geometry for the stone brick slab.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StoneBricksSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	type = 58 # Equivalent to BlockType.Type.STONE_BRICKS_SLAB_BOTTOM
	translation_key = "BLOCK_STONE_BRICKS_SLAB_BOTTOM"
	
	is_solid = true
	is_transparent = true 
	mining_resistance = 2
	
	color_top = Color(0.50, 0.50, 0.52)
	color_side = Color(0.45, 0.45, 0.48)
	color_bottom = Color(0.38, 0.38, 0.40)
	
	texture_file_name = "stone_bricks.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	geometry = BottomSlabGeometry.new()
