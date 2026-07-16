# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/RedwoodLogBlock.gd
# Description: Concrete Domain Definition for the solid colossal Redwood Log.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Redwood Log.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 96
#   (REDWOOD_LOG) to consume "redwood_log.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RedwoodLogBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 96 # OCP Assigned ID for Redwood Log
	translation_key = "BLOCK_REDWOOD_LOG"
	is_solid = true
	is_transparent = false
	
	# Giant conifer logs require 3 impacts to chop
	mining_resistance = 3
	
	# Procedural redwood-red colors for unshaded fallback rendering
	color_top = Color(0.58, 0.25, 0.18)
	color_side = Color(0.52, 0.22, 0.15)
	color_bottom = Color(0.58, 0.25, 0.18)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "redwood_log.png"
	roughness = 0.90 # Extremely rough redwood conifer bark
	metallic = 0.0
	rendering_type = "default"
