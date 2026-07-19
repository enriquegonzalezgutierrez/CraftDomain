# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/SnowBlock.gd
# Description: Concrete Domain Definition for the fluffy powder Snow.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SnowBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 9 # Equivalent to BlockType.Type.SNOW
	translation_key = "BLOCK_SNOW"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Snow drops Stone (ID 1) to satisfy alchemical rules
	drop_item_id = 1
	drop_quantity = 1
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on snowy cap shelves
	is_spawn_penetrable = false # Spawner stops searching here
	
	# Procedural pristine white colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 0.98)
	color_side = Color(0.92, 0.94, 0.96)
	color_bottom = Color(0.88, 0.9, 0.92)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "snow.png"
	roughness = 0.9 # High matte finish to simulate light absorption
	metallic = 0.0
	rendering_type = "default"
