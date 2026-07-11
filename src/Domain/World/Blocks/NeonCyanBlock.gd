# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: NeonCyanBlock
# Description: Concrete Domain Definition for the emissive Cyber Conduit.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Neon Cyan.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Overrides 
#   its local drop variables within the constructor to decouple mining drop tables.
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
	
	# OCP/SOLID Compliance: Cyber cian conduit breaks into Stone Blocks (ID 1)
	drop_item_id = 1
	drop_quantity = 1
	
	# Procedural cyber-cyan colors for unshaded fallback rendering
	color_top = Color(0.06, 0.38, 0.45)
	color_side = Color(0.04, 0.28, 0.35)
	color_bottom = Color(0.02, 0.18, 0.25)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "leaves.png" # Reuses leaf texture for high-frequency patterns
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# EMISSIVE CONFIGURATION:
	# Used by the Infrastructure layer to apply glow shaders and 
	# bake real-time emission without hardcoded logic.
	# ==========================================================================
	is_emissive = true
	emission_color = color_top
	emission_energy = 1.5
