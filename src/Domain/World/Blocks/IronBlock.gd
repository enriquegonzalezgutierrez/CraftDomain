# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: IronBlock
# Description: Concrete Domain Definition for the refined solid Iron Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Iron Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/IronBlock.gd
# ==============================================================================
class_name IronBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 36 # Equivalent to BlockType.Type.IRON_BLOCK
	translation_key = "BLOCK_IRON_BLOCK"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Refined dense metal requires 5 hits to break
	mining_resistance = 5
	
	# Procedural industrial grey steel colors for unshaded fallback
	color_top = Color(0.75, 0.75, 0.78)
	color_side = Color(0.68, 0.68, 0.72)
	color_bottom = Color(0.58, 0.58, 0.62)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "iron_block.png"
	roughness = 0.35 # Semi-smooth polished steel
	metallic = 0.95 # Highly reflective industrial metal
	rendering_type = "default"
