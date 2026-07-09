# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: WaterBlock
# Description: Concrete Domain Definition for the translucent sea fluid.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Defines exclusively the physical,
#   translucency, and fluid rendering parameters for Water.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Uses the 'liquid_water' 
#   rendering type to trigger specialized liquid shaders in Infrastructure 
#   without modifying the core rendering loop.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name WaterBlock
extends BlockDefinition


func _init() -> void:
	super()
	
	# Domain Properties mapping
	type = 6 # Equivalent to BlockType.Type.WATER
	translation_key = "BLOCK_WATER"
	is_solid = false # Entities can swim through this block
	is_transparent = true
	
	# Procedural blue colors with alpha for unshaded fallback rendering
	color_top = Color(0.15, 0.45, 0.85, 0.85)
	color_side = Color(0.12, 0.40, 0.75, 0.85)
	color_bottom = Color(0.10, 0.35, 0.65, 0.85)
	
	# Visual descriptions for PBR rendering
	# Note: Water typically uses a procedural shader, but we define 
	# its physical surface traits here for consistency.
	roughness = 0.06 # Highly glossy
	metallic = 0.12 # Slight specular reflection
	
	# ==========================================================================
	# OCP RENDERING FLAG:
	# Setting this to "liquid_water" tells the Infrastructure mesher to 
	# apply the animated wave shader and liquid face-culling rules.
	# ==========================================================================
	rendering_type = "liquid_water"
