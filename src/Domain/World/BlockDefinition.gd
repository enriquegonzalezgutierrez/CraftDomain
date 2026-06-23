# ==============================================================================
# Project: CraftDomain
# Description: Domain data structure defining the properties and procedural 
#              visual colors of a specific block type.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockDefinition.gd
# ==============================================================================
class_name BlockDefinition
extends RefCounted

## Pure domain data describing a block's traits and look.
## Implements SRP by separating the block concept from the mesh generation.

var type: BlockType.Type
var name: String
var is_solid: bool
var is_transparent: bool

# Procedural coloring for face composition without external assets
var color_top: Color
var color_side: Color
var color_bottom: Color

func _init(
	p_type: BlockType.Type, 
	p_name: String, 
	p_color_top: Color, 
	p_color_side: Color, 
	p_color_bottom: Color
) -> void:
	type = p_type
	name = p_name
	is_solid = BlockType.is_solid(p_type)
	is_transparent = BlockType.is_transparent(p_type)
	color_top = p_color_top
	color_side = p_color_side
	color_bottom = p_color_bottom
