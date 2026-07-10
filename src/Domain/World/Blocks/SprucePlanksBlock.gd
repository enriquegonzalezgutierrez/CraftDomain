# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: SprucePlanksBlock
# Description: Concrete Domain Definition for the refined Spruce Planks block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Spruce Planks.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/SprucePlanksBlock.gd
# ==============================================================================
class_name SprucePlanksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 64 # Equivalent to BlockType.Type.SPRUCE_PLANKS
	translation_key = "BLOCK_SPRUCE_PLANKS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Refined planks require 3 hits to break
	mining_resistance = 3
	
	# Procedural dark chocolate-brown wood colors for unshaded fallback
	color_top = Color(0.38, 0.25, 0.12)
	color_side = Color(0.30, 0.18, 0.08)
	color_bottom = Color(0.24, 0.12, 0.05)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "spruce_planks.png"
	roughness = 0.8 # Sanded matte pine finish
	metallic = 0.0
	rendering_type = "default"
