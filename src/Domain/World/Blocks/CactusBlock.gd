# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: CactusBlock
# Description: Concrete Domain Definition for the solid desert Cactus block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and needle texture configurations for Cactus.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/CactusBlock.gd
# ==============================================================================
class_name CactusBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 78 # Equivalent to BlockType.Type.CACTUS
	translation_key = "BLOCK_CACTUS"
	is_solid = true
	is_transparent = true # Essential for alpha-scissor clipping of needles
	
	# OCP/SOLID Compliance: Fleshy plant tissue breaks easily on 2 hits
	mining_resistance = 2
	
	# Procedural cactus green and needle white colors for unshaded fallback
	color_top = Color(0.18, 0.55, 0.12)
	color_side = Color(0.12, 0.45, 0.08)
	color_bottom = Color(0.08, 0.35, 0.05)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "cactus.png"
	roughness = 0.95 # Matte plant epidermis
	metallic = 0.0
	rendering_type = "default"
