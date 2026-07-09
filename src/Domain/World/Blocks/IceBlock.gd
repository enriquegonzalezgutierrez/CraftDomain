# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: IceBlock
# Description: Concrete Domain Definition for the frozen blue glacial Ice.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and reflective configurations for the Ice Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Can be added 
#   independently to the /Blocks/ directory for automatic discovery.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name IceBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 10 # Equivalent to BlockType.Type.ICE
	translation_key = "BLOCK_ICE"
	is_solid = true
	is_transparent = true # Essential for alpha-blending on the GPU
	
	# Procedural translucent blue colors for unshaded fallback rendering
	color_top = Color(0.62, 0.88, 0.95, 0.75)
	color_side = Color(0.55, 0.82, 0.9, 0.75)
	color_bottom = Color(0.48, 0.75, 0.85, 0.75)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "ice.png"
	
	# ==========================================================================
	# PBR SURFACE PARAMETERS:
	# Low roughness (0.1) creates a glossy, slippery look.
	# Metallic (0.2) adds subtle specular highlights to the frozen surface.
	# ==========================================================================
	roughness = 0.1
	metallic = 0.2
	rendering_type = "default"
