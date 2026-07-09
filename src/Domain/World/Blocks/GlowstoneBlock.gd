# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GlowstoneBlock
# Description: Concrete Domain Definition for the luminous high-end crystal lamp.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Glowstone.
# - Open-Closed Principle (OCP): Extends BlockDefinition. By setting 'is_emissive'
#   to true, the Infrastructure layer will automatically instantiate a 
#   real-time light source at this coordinate.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name GlowstoneBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 30 # Equivalent to BlockType.Type.GLOWSTONE
	translation_key = "BLOCK_GLOWSTONE"
	is_solid = true
	is_transparent = false
	
	# Procedural warm golden colors for unshaded fallback rendering
	color_top = Color(1.0, 0.92, 0.35)
	color_side = Color(0.95, 0.85, 0.25)
	color_bottom = Color(0.85, 0.75, 0.15)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "sand.png" # Reuses the granular texture with high emission
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# HIGH-INTENSITY EMISSION:
	# Glowstone radiates a constant, high-energy warm gold halo.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(1.0, 0.88, 0.35)
	emission_energy = 2.4
