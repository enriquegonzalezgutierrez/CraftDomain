# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: MyceliumBlock
# Description: Concrete Domain Definition for the fungal Mycelium block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Mycelium.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/MyceliumBlock.gd
# ==============================================================================
class_name MyceliumBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 74 # Equivalent to BlockType.Type.MYCELIUM
	translation_key = "BLOCK_MYCELIUM"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Soft organic soil requires only 2 hits
	mining_resistance = 2
	
	# Procedural purple mycelium top and brown soil side colors for unshaded fallback
	color_top = Color(0.48, 0.25, 0.65)
	color_side = Color(0.42, 0.28, 0.18)
	color_bottom = Color(0.35, 0.22, 0.12)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "mycelium_top.png"
	roughness = 0.9 # Matte fungal fibers
	metallic = 0.0
	rendering_type = "default"
