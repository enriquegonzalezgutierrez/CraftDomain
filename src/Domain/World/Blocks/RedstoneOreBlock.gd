# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: RedstoneOreBlock
# Description: Concrete Domain Definition for the glowing Redstone Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Redstone Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/RedstoneOreBlock.gd
# ==============================================================================
class_name RedstoneOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 33 # Equivalent to BlockType.Type.REDSTONE_ORE
	translation_key = "BLOCK_RED_STONE_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Requires 4 hits to extract
	mining_resistance = 4
	
	# Procedural stone-grey and emissive red colors for unshaded fallback
	color_top = Color(0.65, 0.12, 0.15)
	color_side = Color(0.55, 0.08, 0.10)
	color_bottom = Color(0.45, 0.05, 0.08)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "redstone_ore.png"
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# OCP EMISSIVE CONFIGURATION:
	# Redstone veins pulse with a mystical warm ruby-red glow.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(0.95, 0.12, 0.15)
	emission_energy = 1.8
