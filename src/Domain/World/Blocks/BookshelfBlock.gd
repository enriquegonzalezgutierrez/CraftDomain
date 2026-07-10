# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: BookshelfBlock
# Description: Concrete Domain Definition for the wooden Bookshelf block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for the Bookshelf.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/BookshelfBlock.gd
# ==============================================================================
class_name BookshelfBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 56 # Equivalent to BlockType.Type.BOOKSHELF
	translation_key = "BLOCK_BOOKSHELF"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Soft wood bookcase requires only 2 hits to break
	mining_resistance = 2
	
	# Procedural wood-brown colors for unshaded fallback rendering
	color_top = Color(0.72, 0.55, 0.35)
	color_side = Color(0.55, 0.42, 0.28)
	color_bottom = Color(0.72, 0.55, 0.35)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "bookshelf.png"
	roughness = 0.85 # Matte paper and wood
	metallic = 0.0
	rendering_type = "default"
