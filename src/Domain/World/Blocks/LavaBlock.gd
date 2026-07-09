# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: LavaBlock
# Description: Concrete Domain Definition for the volatile high-viscosity Magma.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   emissive, and fluid rendering parameters for Lava.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Uses 'is_emissive' 
#   and 'liquid_lava' metadata to trigger specialized light-emitting shaders 
#   in Infrastructure without hardcoded logic.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name LavaBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 15 # Equivalent to BlockType.Type.LAVA
	translation_key = "BLOCK_LAVA"
	is_solid = false # Entities can pass through (and take damage)
	is_transparent = true
	
	# Procedural glowing orange colors for unshaded fallback rendering
	color_top = Color(1.0, 0.45, 0.0)
	color_side = Color(0.9, 0.35, 0.0)
	color_bottom = Color(0.8, 0.25, 0.0)
	
	# Visual descriptions for PBR rendering
	texture_file_name = "lava.png"
	roughness = 0.95 # Highly viscous matte fluid
	
	# ==========================================================================
	# OCP EMISSIVE & RENDERING CONFIGURATION:
	# Flags used by the Infrastructure layer to instantiate real-time lights
	# and apply the liquid flow shader.
	# ==========================================================================
	rendering_type = "liquid_lava"
	is_emissive = true
	emission_color = Color(1.0, 0.35, 0.0)
	emission_energy = 1.8
