# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: EmeraldOreBlock
# Description: Concrete Domain Definition for the deep Emerald Ore.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Emerald Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/EmeraldOreBlock.gd
# ==============================================================================
class_name EmeraldOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 54 # Equivalent to BlockType.Type.EMERALD_ORE
	translation_key = "BLOCK_EMERALD_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard stone requires 4 hits to extract
	mining_resistance = 4
	
	# Procedural stone-grey and emissive emerald green for unshaded fallback
	color_top = Color(0.12, 0.75, 0.35)
	color_side = Color(0.08, 0.65, 0.28)
	color_bottom = Color(0.05, 0.55, 0.22)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "emerald_ore.png"
	roughness = 0.85
	metallic = 0.1 # Soft crystal specularity
	rendering_type = "default"
	
	# ==========================================================================
	# OCP EMISSIVE CONFIGURATION:
	# Emerald veins pulse with a vibrant, bright green crystalline glow.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(0.0, 0.95, 0.35)
	emission_energy = 1.8
