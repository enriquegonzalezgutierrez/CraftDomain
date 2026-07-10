# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: ObsidianBlock
# Description: Concrete Domain Definition for the ultra-tough Obsidian block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and ultra-high durability traits for Obsidian.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/ObsidianBlock.gd
# ==============================================================================
class_name ObsidianBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 39 # Equivalent to BlockType.Type.OBSIDIAN
	translation_key = "BLOCK_OBSIDIAN"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Legendary volcanic armor block requires 8 hits to shatter!
	mining_resistance = 8
	
	# Procedural deep purple/black colors for unshaded fallback
	color_top = Color(0.08, 0.05, 0.12)
	color_side = Color(0.05, 0.03, 0.08)
	color_bottom = Color(0.02, 0.01, 0.05)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "obsidian.png"
	roughness = 0.05 # Highly glossy, reflective volcanic glass
	metallic = 0.25 # Glassy metallic specularity
	rendering_type = "default"
