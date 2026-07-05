# ==============================================================================
# Project: CraftDomain
# Description: Domain data structure defining the properties, physical geometry, 
#              and procedural visual colors of a specific block type.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively encapsulates block traits, 
#   separating immutable value characteristics from meshing or saving logic.
# - Open-Closed Principle (OCP) & i18n: Replaced hardcoded English string with a 
#   translation key to strictly adhere to OCP for multi-language support.
# - Liskov Substitution Principle (LSP): Dynamically falls back to FullCubeGeometry 
#   if no custom shape is passed, maintaining absolute contract safety.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockDefinition.gd
# ==============================================================================
class_name BlockDefinition
extends RefCounted

var type: BlockType.Type
var translation_key: String # e.g., "BLOCK_STONE"
var is_solid: bool
var is_transparent: bool

# Procedural coloring for face composition without external assets
var color_top: Color
var color_side: Color
var color_bottom: Color

# Pure Domain Geometry Strategy representation
var geometry: IVoxelGeometry


func _init(
	p_type: BlockType.Type, 
	p_translation_key: String, 
	p_color_top: Color, 
	p_color_side: Color, 
	p_color_bottom: Color,
	p_geometry: IVoxelGeometry = null
) -> void:
	type = p_type
	translation_key = p_translation_key
	is_solid = BlockType.is_solid(p_type)
	is_transparent = BlockType.is_transparent(p_type)
	color_top = p_color_top
	color_side = p_color_side
	color_bottom = p_color_bottom
	
	# LSP FALLBACK: If no custom geometry is defined, default to a standard 1x1x1 solid cube
	if p_geometry == null:
		geometry = FullCubeGeometry.new()
	else:
		geometry = p_geometry


## Returns the dynamically translated string based on the active OS locale
func get_localized_name() -> String:
	return tr(translation_key)
