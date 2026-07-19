# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DandelionBlock.gd
# Description: Concrete Domain Definition for the Dandelion yellow flower.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the small Dandelion.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DandelionBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	type = 46 # Equivalent to BlockType.Type.DANDELION
	translation_key = "BLOCK_DANDELION"
	
	is_solid = false
	is_transparent = true 
	mining_resistance = 1
	
	color_top = Color(0.95, 0.90, 0.15)
	color_side = Color(0.85, 0.80, 0.10)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	texture_file_name = "dandelion.png"
	roughness = 0.95 
	metallic = 0.0
	rendering_type = "foliage"
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
