# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: NetherrackBlock
# Description: Concrete Domain Definition for the porous Netherrack block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Netherrack.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/NetherrackBlock.gd
# ==============================================================================
class_name NetherrackBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 76 # Equivalent to BlockType.Type.NETHERRACK
	translation_key = "BLOCK_NETHERRACK"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Soft porous hell rock requires only 2 hits to crumble
	mining_resistance = 2
	
	# Procedural tattered dark-red colors for unshaded fallback rendering
	color_top = Color(0.55, 0.12, 0.12)
	color_side = Color(0.45, 0.08, 0.08)
	color_bottom = Color(0.35, 0.05, 0.05)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "netherrack.png"
	roughness = 0.95 # Highly rough, porous volcanic stone
	metallic = 0.0
	rendering_type = "default"
