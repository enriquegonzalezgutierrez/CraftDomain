# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DeadBushBlock.gd
# Description: Concrete Domain Definition for the Dead Bush desert shrub.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and vegetation configurations for the dry Dead Bush.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Dynamically 
#   registered via auto-scan without altering the core BlockType enum.
# - Liskov Substitution Principle (LSP): Injects the custom CrossQuadGeometry.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DeadBushBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	type = 82 # OCP Assigned ID: Dead Bush
	translation_key = "BLOCK_DEAD_BUSH"
	
	is_solid = false
	is_transparent = true 
	mining_resistance = 1
	is_spawnable_soil = false
	
	color_top = Color(0.55, 0.42, 0.28)
	color_side = Color(0.48, 0.35, 0.22)
	color_bottom = Color(0.35, 0.22, 0.12)
	
	texture_file_name = "dead_bush.png"
	roughness = 0.95 
	metallic = 0.0
	rendering_type = "foliage"
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
