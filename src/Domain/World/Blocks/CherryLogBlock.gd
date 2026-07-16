# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/CherryLogBlock.gd
# Description: Concrete Domain Definition for the solid rose-brown Cherry Log.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Cherry Log.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 83
#   (CHERRY_LOG) to consume "cherry_log.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CherryLogBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 83 # OCP Assigned ID for Cherry Log
	translation_key = "BLOCK_CHERRY_LOG"
	is_solid = true
	is_transparent = false
	
	# Sturdy tree logs require 3 impacts to chop
	mining_resistance = 3
	
	# Procedural rose-brown wood colors for unshaded fallback rendering
	color_top = Color(0.72, 0.45, 0.38)
	color_side = Color(0.65, 0.38, 0.32)
	color_bottom = Color(0.72, 0.45, 0.38)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "cherry_log.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
