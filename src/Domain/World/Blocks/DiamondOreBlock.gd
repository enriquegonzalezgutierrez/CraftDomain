# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Voxel Definitions)
# Class: DiamondOreBlock
# Description: Concrete Domain Definition for the glittering Diamond Ore stone.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and emissive configurations for Diamond Ore.
# - Open-Closed Principle (OCP): Inherits from BlockDefinition. Being placed 
#   inside the /Blocks/ directory allows it to be auto-registered on boot.
#   Specifies its high mining resistance locally within its constructor.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Blocks/DiamondOreBlock.gd
# ==============================================================================
class_name DiamondOreBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 28 # Equivalent to BlockType.Type.DIAMOND_ORE
	translation_key = "BLOCK_DIAMOND_ORE"
	is_solid = true
	is_transparent = false
	
	# OCP/SOLID Compliance: Enforce 5 impacts resistance for precious diamond crystals
	mining_resistance = 5
	
	# Procedural stone-grey colors for unshaded fallback rendering
	color_top = Color(0.35, 0.38, 0.40)
	color_side = Color(0.28, 0.30, 0.32)
	color_bottom = Color(0.25, 0.27, 0.28)
	
	# High-fidelity visual descriptions for Infrastructure PBR compilation
	texture_file_name = "coal_ore.png" # Reuses ore pattern
	roughness = 0.85
	metallic = 0.0
	rendering_type = "default"
	
	# ==========================================================================
	# EMISSIVE ORE CONFIGURATION:
	# Used by the Infrastructure layer to apply glow shaders to the 
	# crystal veins without hardcoded logic in the renderer.
	# ==========================================================================
	is_emissive = true
	emission_color = Color(0.0, 0.95, 0.95) # Intense Cyan crystal glow
	emission_energy = 1.6
