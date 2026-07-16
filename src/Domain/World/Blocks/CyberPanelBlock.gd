# ==============================================================================
# Pathfile: res://src/Domain/World/Blocks/CyberPanelBlock.gd
# Description: Concrete Domain Definition for the solid futuristic Cyber Panel.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Contains exclusively the physical,
#   procedural coloring, and texture configurations for Cyber Panel.
# - Open-Closed Principle (OCP): Extends BlockDefinition. Registers as Type 84
#   (CYBER_PANEL) to consume "cyber_panel.png" from the assets database.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberPanelBlock
extends BlockDefinition


func _init() -> void:
	# Initialize with default 1x1x1 solid cube geometry
	super()
	
	# Domain Properties mapping
	type = 84 # OCP Assigned ID for Cyber Panel
	translation_key = "BLOCK_CYBER_PANEL"
	is_solid = true
	is_transparent = false
	
	# Reinforced industrial plates require 4 impacts to break
	mining_resistance = 4
	
	# Procedural cyber-metallic colors for unshaded fallback rendering
	color_top = Color(0.15, 0.18, 0.22)
	color_side = Color(0.12, 0.14, 0.16)
	color_bottom = Color(0.08, 0.09, 0.11)
	
	# High-fidelity visual descriptions for PBR rendering
	texture_file_name = "cyber_panel.png"
	roughness = 0.35 # Semi-smooth metallic panels
	metallic = 0.85 # Strong metal plate specular reflections
	rendering_type = "default"
	
	# Cyber glow trails setup
	is_emissive = true
	emission_color = Color(0.0, 0.95, 0.95) # Cyber Cyan glow
	emission_energy = 1.2
