# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/AmethystBlock.gd
# Description: Concrete Domain Definition for the solid crystal Amethyst Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Amethyst Block.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 89
#   (AMETHYST_BLOCK) to consume "amethyst.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AmethystBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 89 # OCP Assigned ID for Amethyst Block
	translation_key = "BLOCK_AMETHYST"
	is_solid = true
	is_transparent = false
	
	# Crystal gemstones require 4 impacts to break
	mining_resistance = 4
	
	# Procedural glowing magenta/violet colors for unshaded fallback rendering
	color_top = Color(0.85, 0.25, 0.95)
	color_side = Color(0.65, 0.15, 0.85)
	color_bottom = Color(0.55, 0.10, 0.75)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "amethyst.png"
	roughness = 0.20 # Glassy crystalline sheen
	metallic = 0.30 # Crystal-glass specular reflections
	rendering_type = "default"
	
	# Crystal core glow setup
	is_emissive = true
	emission_color = Color(0.85, 0.25, 0.95) # Violet/Magenta glow
	emission_energy = 1.4
