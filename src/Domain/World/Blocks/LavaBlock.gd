# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/LavaBlock.gd
# Description: Concrete Domain Definition for the volatile high-viscosity Magma.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   emissive, and fluid rendering parameters for Lava.
# - SOLID OCP: Explicitly declares is_liquid as true at domain level.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LavaBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 15 # Equivalent to BlockType.Type.LAVA
	translation_key = "BLOCK_LAVA"
	is_solid = false # Entities can pass through (and take damage)
	is_transparent = true
	is_liquid = true # SOLID OOP definition
	
	# Procedural glowing orange colors for unshaded fallback rendering
	color_top = Color(1.0, 0.45, 0.0)
	color_side = Color(0.9, 0.35, 0.0)
	color_bottom = Color(0.8, 0.25, 0.0)
	
	# Visual descriptions for PBR rendering
	texture_file_name = "lava.png"
	roughness = 0.95 
	rendering_type = "liquid_lava"
	
	is_emissive = true
	emission_color = Color(1.0, 0.35, 0.0)
	emission_energy = 1.8
