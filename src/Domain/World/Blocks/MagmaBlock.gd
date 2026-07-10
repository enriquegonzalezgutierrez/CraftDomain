# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: MagmaBlock
# Description: Concrete Domain Definition for the solid energetic Magma Block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for the Magma Block.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/MagmaBlock.gd
# ==============================================================================
class_name MagmaBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 79 # Equivalent to BlockType.Type.MAGMA
	translation_key = "BLOCK_MAGMA"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Hard volcanic basalt requires 3 hits to break
	mining_resistance = 3
	
	# Procedural charcoal-black and emissive lava-orange for unshaded fallback
	color_top = Color(1.0, 0.45, 0.0)
	color_side = Color(0.12, 0.12, 0.15)
	color_bottom = Color(0.08, 0.08, 0.10)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "magma.png"
	roughness = 0.9 # Rough matte volcanic basalt
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# OCP EMISSIVE CONFIGURATION:
	# Magma cracks pulse with a warm, glowing volcanic geothermal orange light.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(1.0, 0.35, 0.0)
	emission_energy = 2.0
