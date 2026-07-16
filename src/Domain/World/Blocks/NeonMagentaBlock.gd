# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/NeonMagentaBlock.gd
# Description: Concrete Domain Definition for the emissive Cyber Sakura Conduit.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Neon Magenta.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Overrides 
#   its local drop and texture variables within the constructor to 
#   correctly consume "neon_magenta.png" instead of the cherry blossom leaves.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NeonMagentaBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 13 # Equivalent to BlockType.Type.NEON_MAGENTA
	translation_key = "BLOCK_NEON_MAGENTA"
	is_solid = true
	is_transparent = false
	
	# Cyber magenta conduit breaks into Stone Blocks (ID 1)
	drop_item_id = 1
	drop_quantity = 1
	
	# Procedural cyber-magenta colors for unshaded fallback rendering
	color_top = Color(0.24, 0.04, 0.32)
	color_side = Color(0.18, 0.02, 0.24)
	color_bottom = Color(0.12, 0.01, 0.16)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "neon_magenta.png" # CORRECTED: Points directly to neon_magenta asset
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# Emissive setup for high-contrast cyber glow pathways
	is_emissive = true
	emission_color = color_top
	emission_energy = 1.5
