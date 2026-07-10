# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SpruceLogBlock
# Description: Concrete Domain Definition for the solid dark Spruce Log.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Spruce Log.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SpruceLogBlock.gd
# ==============================================================================
class_name SpruceLogBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 63 # Equivalent to BlockType.Type.SPRUCE_LOG
	translation_key = "BLOCK_SPRUCE_LOG"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard pine wood requires 3 hits to chop
	mining_resistance = 3
	
	# Procedural dark-brown colors for unshaded fallback rendering
	color_top = Color(0.45, 0.30, 0.15)
	color_side = Color(0.35, 0.22, 0.10)
	color_bottom = Color(0.45, 0.30, 0.15)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "spruce_log.png"
	roughness = 0.9 # Very rough conifer bark
	metallic = 0.0
	rendering_type = "default"
