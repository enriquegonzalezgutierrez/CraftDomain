# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/AncientRunesBlock.gd
# Description: Concrete Domain Definition for the solid carved Ancient Runes block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Ancient Runes.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 91
#   (ANCIENT_RUNES) to consume "ancient_runes.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AncientRunesBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 91 # OCP Assigned ID for Ancient Runes
	translation_key = "BLOCK_ANCIENT_RUNES"
	is_solid = true
	is_transparent = false
	
	# Ancient carved blocks require 4 impacts to break
	mining_resistance = 4
	
	# Procedural ancient stone-grey colors for unshaded fallback rendering
	color_top = Color(0.48, 0.48, 0.52)
	color_side = Color(0.42, 0.42, 0.45)
	color_bottom = Color(0.35, 0.35, 0.38)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "ancient_runes.png"
	roughness = 0.90 # Dry matte historical stone masonry
	metallic = 0.0
	rendering_type = "default"
	
	# Runic glow trails setup
	is_emissive = true
	emission_color = Color(0.3, 0.85, 1.0) # Soft cyan/blue magical rune glow
	emission_energy = 0.8
