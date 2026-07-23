# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/CoalOreBlock.gd
# Description: Concrete Domain Definition for the Coal Ore stone block.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CoalOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 21 # Equivalent to BlockType.Type.COAL_ORE
	translation_key = "BLOCK_COAL_ORE"
	is_solid = true
	is_transparent = false
	
	# Coal ore requires 3 impacts to mine
	mining_resistance = 3
	
	# Procedural stone-grey and coal-black colors for unshaded fallback rendering
	color_top = Color(0.28, 0.28, 0.30)
	color_side = Color(0.22, 0.22, 0.24)
	color_bottom = Color(0.18, 0.18, 0.20)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "coal_ore.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
