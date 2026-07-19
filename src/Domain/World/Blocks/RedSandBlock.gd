# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/RedSandBlock.gd
# Description: Concrete Domain Definition for the Terracotta Red Sand.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RedSandBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 8 # Equivalent to BlockType.Type.RED_SAND
	translation_key = "BLOCK_RED_SAND"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Red sand deposits crumble and drop Dirt Blocks (ID 2)
	drop_item_id = 2
	drop_quantity = 1
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on badlands sand steps
	is_spawn_penetrable = false # Spawner stops searching here
	
	# Procedural terracotta orange colors for unshaded fallback rendering
	color_top = Color(0.88, 0.42, 0.25)
	color_side = Color(0.82, 0.35, 0.20)
	color_bottom = Color(0.75, 0.30, 0.15)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "red_sand.png"
	roughness = 0.88 
	metallic = 0.0
	rendering_type = "default"
