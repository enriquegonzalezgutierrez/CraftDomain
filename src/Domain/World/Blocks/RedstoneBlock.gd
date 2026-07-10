# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RedstoneBlock
# Description: Concrete Domain Definition for the solid energetic Redstone Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for the Redstone Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/RedstoneBlock.gd
# ==============================================================================
class_name RedstoneBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 38 # Equivalent to BlockType.Type.REDSTONE_BLOCK
	translation_key = "BLOCK_RED_STONE_BLOCK"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Crystalline structure requires 4 hits to break
	mining_resistance = 4
	
	# Procedural energetic red colors for unshaded fallback
	color_top = Color(0.85, 0.05, 0.08)
	color_side = Color(0.75, 0.03, 0.06)
	color_bottom = Color(0.65, 0.01, 0.04)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "redstone_block.png"
	roughness = 0.55
	metallic = 0.2 # Slight crystalline gloss
	rendering_type = "default"
	
	# ==========================================================================
	# OCP EMISSIVE CONFIGURATION:
	# Concentrated redstone blocks pulse with an intense, warm scarlet light.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(0.95, 0.05, 0.08)
	emission_energy = 2.2
