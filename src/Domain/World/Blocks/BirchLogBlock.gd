# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: BirchLogBlock
# Description: Concrete Domain Definition for the slender silver Birch Log.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Birch Log.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name BirchLogBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 24 # Equivalent to BlockType.Type.BIRCH_LOG
	translation_key = "BLOCK_BIRCH_LOG"
	is_solid = true
	is_transparent = false
	
	# Procedural silver-white wood colors for unshaded fallback rendering
	color_top = Color(0.92, 0.92, 0.94)
	color_side = Color(0.88, 0.88, 0.90)
	color_bottom = Color(0.92, 0.92, 0.94)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "birch_log.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
