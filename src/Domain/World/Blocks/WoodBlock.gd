# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/WoodBlock.gd
# Description: Concrete Domain Definition for the solid structural Oak Wood Log.
#              Declares polymorphic spawn penetration rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WoodBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 4 # Equivalent to BlockType.Type.WOOD
	translation_key = "BLOCK_WOOD"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Enforce 3 impacts resistance for sturdy Oak logs
	mining_resistance = 3
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = false # No spawning on top of wooden structures
	is_spawn_penetrable = true # Spawner can search through wooden roofs/ceilings
	
	# Procedural wood-brown colors for unshaded fallback rendering
	color_top = Color(0.72, 0.55, 0.35)
	color_side = Color(0.55, 0.42, 0.28)
	color_bottom = Color(0.72, 0.55, 0.35)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "wood.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
