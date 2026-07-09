# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: CloudBlock
# Description: Concrete Domain Definition for the semi-transparent vapor pad.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   transparency, and texture configurations for the Cloud Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name CloudBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 14 # Equivalent to BlockType.Type.CLOUD
	translation_key = "BLOCK_CLOUD"
	is_solid = false # Entities pass through vapor
	is_transparent = true
	
	# Procedural soft white colors with alpha for unshaded fallback rendering
	color_top = Color(1.0, 1.0, 1.0, 0.65)
	color_side = Color(0.95, 0.95, 0.95, 0.65)
	color_bottom = Color(0.9, 0.9, 0.9, 0.65)
	
	# Visual descriptions for PBR texture mapping
	texture_file_name = "sand.png" # Reuses smooth granular texture for noise
	roughness = 0.9 # High matte finish for a vaporous look
	metallic = 0.0
	rendering_type = "default"
