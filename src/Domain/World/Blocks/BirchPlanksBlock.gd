# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/BirchPlanksBlock.gd
# Description: Concrete Domain Definition for the refined pale Birch Planks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Birch Planks.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 81
#   (BIRCH_PLANKS) to consume "birch_planks.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BirchPlanksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 81 # OCP Assigned ID for Birch Planks
	translation_key = "BLOCK_BIRCH_PLANKS"
	is_solid = true
	is_transparent = false
	
	# Refined wood requires 2 impacts to break
	mining_resistance = 2
	
	# Procedural pale cream-yellow wood colors for unshaded fallback rendering
	color_top = Color(0.92, 0.88, 0.72)
	color_side = Color(0.85, 0.82, 0.65)
	color_bottom = Color(0.78, 0.75, 0.58)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "birch_planks.png"
	roughness = 0.8
	metallic = 0.0
	rendering_type = "default"
