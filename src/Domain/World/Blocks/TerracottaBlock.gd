# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: TerracottaBlock
# Description: Concrete Domain Definition for the smooth Terracotta block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Terracotta Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/TerracottaBlock.gd
# ==============================================================================
class_name TerracottaBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 59 # Equivalent to BlockType.Type.TERRACOTTA
	translation_key = "BLOCK_TERRACOTTA"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hardened clay requires 3 hits to break
	mining_resistance = 3
	
	# Procedural smooth red-orange terracotta clay colors for unshaded fallback
	color_top = Color(0.72, 0.35, 0.22)
	color_side = Color(0.65, 0.30, 0.18)
	color_bottom = Color(0.55, 0.25, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "terracotta.png"
	roughness = 0.95 # Highly matte, dry clay texture
	metallic = 0.0
	rendering_type = "default"
