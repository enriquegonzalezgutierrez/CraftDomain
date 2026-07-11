# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: NeonMagentaBlock
# Description: Concrete Domain Definition for the emissive Cyber Sakura Conduit.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and wind-sway emissive configurations for Neon Magenta.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Overrides 
#   its local drop variables within the constructor to decouple mining drop tables.
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
	
	# OCP/SOLID Compliance: Cyber magenta conduit breaks into Stone Blocks (ID 1)
	drop_item_id = 1
	drop_quantity = 1
	
	# Procedural cyber-magenta colors for unshaded fallback rendering
	color_top = Color(0.24, 0.04, 0.32)
	color_side = Color(0.18, 0.02, 0.24)
	color_bottom = Color(0.12, 0.01, 0.16)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "sakura_leaves.png"
	roughness = 0.85
	metallic = 0.0
	
	# ==========================================================================
	# HYBRID RENDERING CONFIGURATION:
	# 'foliage' triggers the wind-sway vertex displacement shader.
	# 'is_emissive' triggers the glow fragment shader.
	# ==========================================================================
	rendering_type = "foliage"
	is_emissive = true
	emission_color = color_top
	emission_energy = 1.5
