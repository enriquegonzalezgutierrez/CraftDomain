# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/DiamondBlock.gd
# Description: Concrete Domain Definition for the solid refined Diamond Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Diamond Block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 88
#   (DIAMOND_BLOCK) to consume "diamond_block.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DiamondBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 88 # OCP Assigned ID for Diamond Block
	translation_key = "BLOCK_DIAMOND"
	is_solid = true
	is_transparent = false
	
	# Solid gemstones require 5 impacts to break
	mining_resistance = 5
	
	# Procedural glowing cyan colors for unshaded fallback rendering
	color_top = Color(0.2, 0.95, 0.95)
	color_side = Color(0.15, 0.85, 0.85)
	color_bottom = Color(0.1, 0.75, 0.75)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "diamond_block.png"
	roughness = 0.15 # Glassy glossy gemstone sheen
	metallic = 0.35 # Diamond metallic-crystal specular reflections
	rendering_type = "default"
	
	# Crystal core glow setup
	is_emissive = true
	emission_color = Color(0.0, 0.95, 0.95) # Radiant Cyan glow
	emission_energy = 1.5
