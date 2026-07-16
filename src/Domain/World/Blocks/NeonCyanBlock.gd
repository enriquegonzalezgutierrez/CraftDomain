# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/NeonCyanBlock.gd
# Description: Concrete Domain Definition for the emissive Cyber Conduit.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Neon Cyan.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Overrides 
#   its local drop and texture variables within the constructor to 
#   correctly consume "neon_cyan.png" instead of the forest leaves.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NeonCyanBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 12 # Equivalent to BlockType.Type.NEON_CYAN
	translation_key = "BLOCK_NEON_CYAN"
	is_solid = true
	is_transparent = false
	
	# Cyber cyan conduit breaks into Stone Blocks (ID 1)
	drop_item_id = 1
	drop_quantity = 1
	
	# Procedural cyber-cyan colors for unshaded fallback rendering
	color_top = Color(0.06, 0.38, 0.45)
	color_side = Color(0.04, 0.28, 0.35)
	color_bottom = Color(0.02, 0.18, 0.25)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "neon_cyan.png" # CORRECTED: Points directly to neon_cyan asset
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# Emissive setup for high-contrast cyber glow pathways
	is_emissive = true
	emission_color = color_top
	emission_energy = 1.5
