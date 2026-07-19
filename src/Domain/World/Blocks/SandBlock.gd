# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/SandBlock.gd
# Description: Concrete Domain Definition for the fine granular beach Sand.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on sandy shores
	is_spawn_penetrable = false # Spawner stops searching here
	
	# Procedural yellow-sand colors for unshaded fallback rendering
	color_top = Color(0.95, 0.90, 0.65)
	color_side = Color(0.88, 0.82, 0.58)
	color_bottom = Color(0.82, 0.75, 0.52)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "sand.png"
	roughness = 0.88 # High roughness for a granular matte finish
	metallic = 0.0
	rendering_type = "default"
