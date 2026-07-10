# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SolidSnowBlock
# Description: Concrete Domain Definition for the compressed Solid Snow block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Solid Snow.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SolidSnowBlock.gd
# ==============================================================================
class_name SolidSnowBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 49 # Equivalent to BlockType.Type.SOLID_SNOW
	translation_key = "BLOCK_SOLID_SNOW"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Compressed solid snow blocks require 2 hits
	mining_resistance = 2
	
	# Procedural pristine white colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 0.98)
	color_side = Color(0.92, 0.94, 0.96)
	color_bottom = Color(0.88, 0.9, 0.92)
	
	# Visual descriptions for PBR texture mapping (Reuses snow texture!)
	texture_file_name = "snow.png"
	roughness = 0.9 # High matte finish to simulate light absorption
	metallic = 0.0
	rendering_type = "default"
