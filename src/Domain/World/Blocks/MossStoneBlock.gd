# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/MossStoneBlock.gd
# Description: Concrete Domain Definition for the Moss Stone block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Moss Stone.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 95
#   (MOSS_STONE) to consume "moss_stone.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MossStoneBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 95 # OCP Assigned ID for Moss Stone
	translation_key = "BLOCK_MOSS_STONE"
	is_solid = true
	is_transparent = false
	
	# Ancient moss-covered rocks require 3 impacts to mine
	mining_resistance = 3
	
	# Procedural forest-grey and mossy-green colors for unshaded fallback rendering
	color_top = Color(0.35, 0.48, 0.25)
	color_side = Color(0.38, 0.38, 0.40)
	color_bottom = Color(0.32, 0.32, 0.35)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "moss_stone.png"
	roughness = 0.90 # Dry matte textured stone and moss
	metallic = 0.0
	rendering_type = "default"
