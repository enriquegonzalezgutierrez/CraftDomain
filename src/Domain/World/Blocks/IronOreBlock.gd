# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/IronOreBlock.gd
# Description: Concrete Domain Definition for the raw Iron Ore stone.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Iron Ore.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 31
#   (IRON_ORE) to consume "iron_ore.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IronOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 31 # Equivalent to BlockType.Type.IRON_ORE
	translation_key = "BLOCK_IRON_ORE"
	is_solid = true
	is_transparent = false
	
	# Enforce 4 impacts resistance for heavy metal ore mining balance
	mining_resistance = 4
	
	# Procedural stone-grey and orange-brown rust colors for unshaded fallback
	color_top = Color(0.62, 0.45, 0.32)
	color_side = Color(0.48, 0.48, 0.50)
	color_bottom = Color(0.38, 0.38, 0.40)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "iron_ore.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
