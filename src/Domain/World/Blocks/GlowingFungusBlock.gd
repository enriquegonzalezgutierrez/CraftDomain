# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/GlowingFungusBlock.gd
# Description: Concrete Domain Definition for the Glowing Fungus block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Glowing Fungus.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 92
#   (GLOWING_FUNGUS) to consume "glowing_fungus.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GlowingFungusBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 92 # OCP Assigned ID for Glowing Fungus
	translation_key = "BLOCK_GLOWING_FUNGUS"
	is_solid = false # Entities can walk through organic foliage/moss
	is_transparent = true # For alpha scissor transparency clipping
	
	# Soft organic fibers break instantly on 1 impact
	mining_resistance = 1
	
	# Procedural glowing cyan/green colors for unshaded fallback rendering
	color_top = Color(0.2, 0.95, 0.45, 0.72)
	color_side = Color(0.15, 0.85, 0.35, 0.72)
	color_bottom = Color(0.1, 0.75, 0.25, 0.72)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "glowing_fungus.png"
	roughness = 0.95 # Highly matte organic plant fibers
	metallic = 0.0
	rendering_type = "foliage" # Sways with wind shaders
	
	# Core mystical spore glow setup
	is_emissive = true
	emission_color = Color(0.0, 0.95, 0.45) # Bio-luminescent green-cyan glow
	emission_energy = 1.6
