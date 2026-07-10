# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: BlueWoolBlock
# Description: Concrete Domain Definition for the soft Blue Wool block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and soft texture configurations for the Blue Wool Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/BlueWoolBlock.gd
# ==============================================================================
class_name BlueWoolBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 43 # Equivalent to BlockType.Type.BLUE_WOOL
	translation_key = "BLOCK_BLUE_WOOL"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Soft wool fabric breaks instantly on 1 hit
	mining_resistance = 1
	
	# Procedural deep blue colors for unshaded fallback
	color_top = Color(0.15, 0.35, 0.85)
	color_side = Color(0.10, 0.28, 0.75)
	color_bottom = Color(0.08, 0.22, 0.65)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "blue_wool.png"
	roughness = 1.0 # Absolutely matte fabric fibers
	metallic = 0.0
	rendering_type = "default"
