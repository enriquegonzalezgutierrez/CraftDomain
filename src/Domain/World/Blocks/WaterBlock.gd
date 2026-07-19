# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/WaterBlock.gd
# Description: Concrete Domain Definition for the translucent sea fluid.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   translucency, and fluid rendering parameters for Water.
# - SOLID OCP: Explicitly declares is_liquid as true at domain level.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WaterBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 6 # Equivalent to BlockType.Type.WATER
	translation_key = "BLOCK_WATER"
	is_solid = false # Entities can swim through this block
	is_transparent = true
	is_liquid = true # SOLID OOP definition
	
	# Procedural blue colors with alpha for unshaded fallback rendering
	color_top = Color(0.15, 0.45, 0.85, 0.85)
	color_side = Color(0.12, 0.40, 0.75, 0.85)
	color_bottom = Color(0.10, 0.35, 0.65, 0.85)
	
	# Visual descriptions for PBR rendering
	roughness = 0.06 
	metallic = 0.12 
	rendering_type = "liquid_water"
