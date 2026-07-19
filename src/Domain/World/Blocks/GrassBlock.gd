# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/GrassBlock.gd
# Description: Concrete Domain Definition for the vibrant Grass Block.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GrassBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 3 # Equivalent to BlockType.Type.GRASS
	translation_key = "BLOCK_GRASS"
	is_solid = true
	is_transparent = false
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on grassy plains
	is_spawn_penetrable = false # Spawner stops searching here
	
	# ==========================================================================
	# PROCEDURAL COLOR PALETTE:
	# Symmetrical colors for unshaded fallback: vibrant green on top 
	# with loose organic soil on sides and bottom faces.
	# ==========================================================================
	color_top = Color(0.42, 0.78, 0.25)
	color_side = Color(0.48, 0.32, 0.20)
	color_bottom = Color(0.42, 0.28, 0.18)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "grass_top.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
