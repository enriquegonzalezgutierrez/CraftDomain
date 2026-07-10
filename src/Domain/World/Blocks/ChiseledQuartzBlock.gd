# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: ChiseledQuartzBlock
# Description: Concrete Domain Definition for the Chiseled Quartz Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Chiseled Quartz.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/ChiseledQuartzBlock.gd
# ==============================================================================
class_name ChiseledQuartzBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 72 # Equivalent to BlockType.Type.CHISELED_QUARTZ
	translation_key = "BLOCK_CHISELED_QUARTZ"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Polished quartz column requires 3 hits to break
	mining_resistance = 3
	
	# Procedural pure white marble colors for unshaded fallback rendering
	color_top = Color(0.98, 0.98, 1.0)
	color_side = Color(0.92, 0.92, 0.95)
	color_bottom = Color(0.85, 0.85, 0.88)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "chiseled_quartz.png"
	roughness = 0.35 # Semi-smooth polished finish
	metallic = 0.05
	rendering_type = "default"
