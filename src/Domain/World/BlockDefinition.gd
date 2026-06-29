# ==============================================================================
# Project: CraftDomain
# Description: Domain data structure defining the properties and procedural 
#              visual colors of a specific block type.
#              SOLID/i18n UPGRADE: Replaced hardcoded English string with a 
#              translation key to strictly adhere to OCP for multi-language support.
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

func _init(
	p_type: BlockType.Type, 
	p_translation_key: String, 
	p_color_top: Color, 
	p_color_side: Color, 
	p_color_bottom: Color
) -> void:
	type = p_type
	translation_key = p_translation_key
	is_solid = BlockType.is_solid(p_type)
	is_transparent = BlockType.is_transparent(p_type)
	color_top = p_color_top
	color_side = p_color_side
	color_bottom = p_color_bottom

## Returns the dynamically translated string based on the active OS locale
func get_localized_name() -> String:
	return tr(translation_key)
