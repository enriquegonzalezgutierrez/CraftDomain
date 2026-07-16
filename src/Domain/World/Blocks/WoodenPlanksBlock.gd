# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/WoodenPlanksBlock.gd
# Description: Concrete Domain Definition for the standard Wooden Planks block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Wooden Planks.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 99
#   (WOODEN_PLANKS) to consume "wooden_planks.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WoodenPlanksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 99 # OCP Assigned ID for Wooden Planks
	translation_key = "BLOCK_WOODEN_PLANKS"
	is_solid = true
	is_transparent = false
	
	# Standard wood planks require 2 impacts to break
	mining_resistance = 2
	
	# Procedural wood-brown colors for unshaded fallback rendering
	color_top = Color(0.85, 0.65, 0.40)
	color_side = Color(0.75, 0.55, 0.30)
	color_bottom = Color(0.65, 0.45, 0.25)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "wooden_planks.png"
	roughness = 0.80 # Matte sanded wood
	metallic = 0.0
	rendering_type = "default"
