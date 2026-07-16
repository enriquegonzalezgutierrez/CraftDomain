# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/WarningStripesBlock.gd
# Description: Concrete Domain Definition for the industrial Hazard Warning Stripes block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Warning Stripes.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 98
#   (WARNING_STRIPES) to consume "warning_stripes.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WarningStripesBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 98 # OCP Assigned ID for Warning Stripes
	translation_key = "BLOCK_WARNING_STRIPES"
	is_solid = true
	is_transparent = false
	
	# Industrial composite blocks require 3 impacts to break
	mining_resistance = 3
	
	# Procedural bright yellow hazard colors for unshaded fallback rendering
	color_top = Color(0.95, 0.78, 0.12)
	color_side = Color(0.12, 0.12, 0.15)
	color_bottom = Color(0.12, 0.12, 0.15)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "warning_stripes.png"
	roughness = 0.50 # Semi-matte safety plastic coating
	metallic = 0.1
	rendering_type = "default"
