# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GlassBlock
# Description: Concrete Domain Definition for the transparent fused silica Glass.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   transparency, and light-reflection configurations for the Glass Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Can be added 
#   to the world dynamically without modifying the central rendering engine.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name GlassBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 23 # Equivalent to BlockType.Type.GLASS
	translation_key = "BLOCK_GLASS"
	is_solid = true
	is_transparent = true # Essential for alpha-blending and depth sorting
	
	# Procedural translucent blue colors for unshaded fallback rendering
	color_top = Color(0.85, 0.95, 1.0, 0.35)
	color_side = Color(0.80, 0.92, 0.98, 0.35)
	color_bottom = Color(0.75, 0.88, 0.95, 0.35)
	
	# High-fidelity visual descriptions for PBR texture mapping
	texture_file_name = "glass.png"
	
	# ==========================================================================
	# PBR REFLECTION PARAMETERS:
	# Low roughness (glossy) and slight metallic value to simulate 
	# industrial-grade glass reflections.
	# ==========================================================================
	roughness = 0.05 
	metallic = 0.1
	rendering_type = "default"
