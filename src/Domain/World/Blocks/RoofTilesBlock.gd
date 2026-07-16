# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/RoofTilesBlock.gd
# Description: Concrete Domain Definition for the rustic tiled Roof Tiles block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Roof Tiles.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 97
#   (ROOF_TILES) to consume "roof_tiles.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RoofTilesBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 97 # OCP Assigned ID for Roof Tiles
	translation_key = "BLOCK_ROOF_TILES"
	is_solid = true
	is_transparent = false
	
	# Clay roof tiles require 3 impacts to mine
	mining_resistance = 3
	
	# Procedural terracotta-red colors for unshaded fallback rendering
	color_top = Color(0.68, 0.32, 0.22)
	color_side = Color(0.58, 0.25, 0.18)
	color_bottom = Color(0.48, 0.18, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "roof_tiles.png"
	roughness = 0.85 # Dry semi-rough baked clay
	metallic = 0.05
	rendering_type = "default"
