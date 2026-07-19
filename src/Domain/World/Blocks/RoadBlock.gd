# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/RoadBlock.gd
# Description: Concrete Domain Definition for the asphalt Paved Road.
#              Declares polymorphic spawn surface rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RoadBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 25 # Equivalent to BlockType.Type.ROAD
	translation_key = "BLOCK_ROAD"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Enforce 3 impacts resistance for dense asphalt roads
	mining_resistance = 3
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = true # Mobs can stand on paved roads
	is_spawn_penetrable = false # Spawner stops searching here
	
	# Procedural dark asphalt colors for unshaded fallback rendering
	color_top = Color(0.24, 0.24, 0.28)
	color_side = Color(0.18, 0.18, 0.22)
	color_bottom = Color(0.24, 0.24, 0.28)
	
	# High-fidelity visual descriptions for PBR texture mapping
	texture_file_name = "road.png"
	roughness = 0.55 # Semi-smooth asphalt finish
	metallic = 0.0
	rendering_type = "default"
