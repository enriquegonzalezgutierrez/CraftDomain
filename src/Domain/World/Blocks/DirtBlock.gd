# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DirtBlock.gd
# Description: Concrete Domain Definition for the loose organic Dirt Block.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DirtBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 2 # Equivalent to BlockType.Type.DIRT
	translation_key = "BLOCK_DIRT"
	is_solid = true
	is_transparent = false
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on fertile dirt soil
	is_spawn_penetrable = false # Spawner stops searching here
	
	# Procedural organic brown colors for unshaded fallback rendering
	color_top = Color(0.55, 0.38, 0.25)
	color_side = Color(0.48, 0.32, 0.20)
	color_bottom = Color(0.42, 0.28, 0.18)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "dirt.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
