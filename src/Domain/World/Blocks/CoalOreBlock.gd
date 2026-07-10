# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: GoldOreBlock
# Description: Concrete Domain Definition for the deep Gold Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Gold Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/GoldOreBlock.gd
# ==============================================================================
class_name GoldOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 32 # Equivalent to BlockType.Type.GOLD_ORE
	translation_key = "BLOCK_GOLD_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Tougher block requires 4 hits to extract
	mining_resistance = 4
	
	# Procedural stone-grey and yellow gold colors for unshaded fallback
	color_top = Color(0.65, 0.58, 0.22)
	color_side = Color(0.55, 0.48, 0.15)
	color_bottom = Color(0.45, 0.38, 0.10)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "gold_ore.png"
	roughness = 0.65 # Polished ore highlights
	metallic = 0.6 # Glittering gold specularity
	rendering_type = "default"
