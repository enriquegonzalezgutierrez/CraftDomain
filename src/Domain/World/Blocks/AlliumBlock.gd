# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/AlliumBlock.gd
# Description: Concrete Domain Definition for the purple wild Allium flower.
#              Declares polymorphic spawn penetration rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AlliumBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with parent constructor
	super()
	
	# Domain Properties mapping
	type = 100 # OCP Assigned ID for Allium Flower
	translation_key = "BLOCK_ALLIUM"
	
	# Physical Properties: Non-solid, transparent for alpha-scissor clipping
	is_solid = false
	is_transparent = true
	mining_resistance = 1
	
	# SOLID OCP Spawning properties configuration
	is_spawn_surface = false # Entities cannot stand on top of flower petals
	is_spawn_penetrable = true # Spawner can search through the flower to find the soil below
	
	# Procedural purple pom-pom flower colors for unshaded fallback rendering
	color_top = Color(0.85, 0.25, 0.95)
	color_side = Color(0.72, 0.20, 0.82)
	color_bottom = Color(0.25, 0.55, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "allium.png"
	roughness = 0.95 # Matte flower petals
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Injects the cross-quad geometry strategy
	geometry = CrossQuadGeometry.new()
