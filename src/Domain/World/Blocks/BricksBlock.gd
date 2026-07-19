# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/BricksBlock.gd
# Description: Concrete Domain Definition for the fortress red Bricks.
#              Declares polymorphic spawn penetration rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BricksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 22 # Equivalent to BlockType.Type.BRICKS
	translation_key = "BLOCK_BRICKS"
	is_solid = true
	is_transparent = false
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = false # No spawning on top of fortress brick roofs
	is_spawn_penetrable = true # Spawner can search through brick ceilings
	
	# Procedural baked-clay colors for unshaded fallback rendering
	color_top = Color(0.65, 0.28, 0.22)
	color_side = Color(0.58, 0.22, 0.18)
	color_bottom = Color(0.52, 0.18, 0.15)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "bricks.png"
	roughness = 0.8 # Standard rough masonry finish
	metallic = 0.0
	rendering_type = "default"
