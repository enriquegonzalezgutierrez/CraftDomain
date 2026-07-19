# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/OrchidBlock.gd
# Description: Concrete Domain Definition for the Blue Orchid flower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the small Blue Orchid.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OrchidBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	type = 61 # Equivalent to BlockType.Type.BLUE_ORCHID
	translation_key = "BLOCK_BLUE_ORCHID"
	
	is_solid = false
	is_transparent = true 
	mining_resistance = 1
	
	color_top = Color(0.15, 0.55, 0.95)
	color_side = Color(0.10, 0.45, 0.85)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	texture_file_name = "blue_orchid.png"
	roughness = 0.95 
	metallic = 0.0
	rendering_type = "foliage"
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
