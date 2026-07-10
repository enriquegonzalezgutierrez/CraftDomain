# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: LapisOreBlock
# Description: Concrete Domain Definition for the Lapis Lazuli Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Lapis Lazuli Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/LapisOreBlock.gd
# ==============================================================================
class_name LapisOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 44 # Equivalent to BlockType.Type.LAPIS_ORE
	translation_key = "BLOCK_LAPIS_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard stone requires 4 hits to extract
	mining_resistance = 4
	
	# Procedural stone-grey and royal blue colors for unshaded fallback
	color_top = Color(0.12, 0.35, 0.65)
	color_side = Color(0.08, 0.28, 0.55)
	color_bottom = Color(0.05, 0.22, 0.45)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "lapis_ore.png"
	roughness = 0.85
	metallic = 0.1 # Soft crystal specularity
	rendering_type = "default"
