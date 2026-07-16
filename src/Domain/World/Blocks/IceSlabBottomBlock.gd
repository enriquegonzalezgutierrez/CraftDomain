# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/IceSlabBottomBlock.gd
# Description: Concrete Domain Definition for the Ice Slab (Bottom half).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and custom half-height geometry for the ice slab.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IceSlabBottomBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	type = 60 # Equivalent to BlockType.Type.ICE_SLAB_BOTTOM
	translation_key = "BLOCK_ICE_SLAB_BOTTOM"
	
	is_solid = true
	is_transparent = true 
	mining_resistance = 2
	
	color_top = Color(0.62, 0.88, 0.95, 0.75)
	color_side = Color(0.55, 0.82, 0.9, 0.75)
	color_bottom = Color(0.48, 0.75, 0.85, 0.75)
	
	texture_file_name = "ice.png"
	roughness = 0.1 
	metallic = 0.2
	rendering_type = "default"
	
	geometry = BottomSlabGeometry.new()
