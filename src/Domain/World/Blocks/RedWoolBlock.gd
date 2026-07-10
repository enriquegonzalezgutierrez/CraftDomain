# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RedWoolBlock
# Description: Concrete Domain Definition for the soft Red Wool block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and soft texture configurations for the Red Wool Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/RedWoolBlock.gd
# ==============================================================================
class_name RedWoolBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 42 # Equivalent to BlockType.Type.RED_WOOL
	translation_key = "BLOCK_RED_WOOL"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Soft wool fabric breaks instantly on 1 hit
	mining_resistance = 1
	
	# Procedural warm red colors for unshaded fallback
	color_top = Color(0.85, 0.15, 0.15)
	color_side = Color(0.75, 0.10, 0.10)
	color_bottom = Color(0.65, 0.08, 0.08)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "red_wool.png"
	roughness = 1.0 # Absolutely matte, rough fabric fibers
	metallic = 0.0
	rendering_type = "default"
