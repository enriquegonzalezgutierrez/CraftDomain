# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: CropGrowingBlock
# Description: Concrete Domain Definition for the Crop Growing (medium wheat stalks).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   translucency, and wind-sway configurations for the growing wheat stalks.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# - Liskov Substitution Principle (LSP): Inherits from BlockDefinition, 
#   integrating seamlessly with the world mesher and raycast pipelines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/CropGrowingBlock.gd
# ==============================================================================
class_name CropGrowingBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 geometry
	super()
	
	# Domain Properties mapping
	type = 19 # Equivalent to BlockType.Type.CROP_GROWING
	translation_key = "BLOCK_CROP_GROWING"
	
	# Physical Properties: Entities must walk through crops without collision
	is_solid = false
	is_transparent = true # Essential for alpha-scissor clipping in shaders
	
	# Procedural green-yellow colors for unshaded fallback rendering
	color_top = Color(0.65, 0.85, 0.25, 0.72)
	color_side = Color(0.58, 0.75, 0.20, 0.72)
	color_bottom = Color(0.52, 0.65, 0.15, 0.72)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "crop_growing.png"
	roughness = 0.95 # Highly matte plant fibers
	metallic = 0.0
	
	# ==========================================================================
	# OCP FOLIAGE RENDERING FLAG:
	# Setting this to "foliage" tells the ChunkNode to apply the 
	# wind-sway vertex displacement shader, making the stalks sway.
	# ==========================================================================
	rendering_type = "foliage"
