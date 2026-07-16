# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/GraniteBlock.gd
# Description: Concrete Domain Definition for the heavy igneous Granite block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Granite Block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 93
#   (GRANITE_BLOCK) to consume "granite.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GraniteBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 93 # OCP Assigned ID for Granite Block
	translation_key = "BLOCK_GRANITE"
	is_solid = true
	is_transparent = false
	
	# Igneous granite rock requires 4 impacts to mine
	mining_resistance = 4
	
	# Procedural rusty-grey granite colors for unshaded fallback rendering
	color_top = Color(0.65, 0.48, 0.45)
	color_side = Color(0.55, 0.42, 0.38)
	color_bottom = Color(0.48, 0.35, 0.32)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "granite.png"
	roughness = 0.90 # Dry matte textured stone
	metallic = 0.0
	rendering_type = "default"
