# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: NetherBricksBlock
# Description: Concrete Domain Definition for the dark solid Nether Bricks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Nether Bricks.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/NetherBricksBlock.gd
# ==============================================================================
class_name NetherBricksBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 77 # Equivalent to BlockType.Type.NETHER_BRICKS
	translation_key = "BLOCK_NETHER_BRICKS"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard nether masonry requires 3 hits to break
	mining_resistance = 3
	
	# Procedural deep obsidian-red colors for unshaded fallback rendering
	color_top = Color(0.32, 0.05, 0.08)
	color_side = Color(0.24, 0.03, 0.05)
	color_bottom = Color(0.18, 0.01, 0.03)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "nether_bricks.png"
	roughness = 0.85 # Elegant semi-matte finish
	metallic = 0.0
	rendering_type = "default"
