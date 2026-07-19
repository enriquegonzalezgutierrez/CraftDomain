# ==============================================================================
# Pathfile: res://src/Domain/World/BlockDefinition.gd
# Description: Pure Domain Base Class describing the physical attributes, 
#              geographical properties, spawning behaviors, and decoupled 
#              visual characteristics of a voxel block.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BlockDefinition
extends RefCounted

# ==============================================================================
# DOMAIN CORE PROPERTIES (DDD Compliance)
# ==============================================================================
## Generic integer mapping for block type. 
## Set in subclass constructors (e.g. BlockType.Type.STONE).
var type: int

## Translation localization key (e.g., "BLOCK_STONE")
var translation_key: String

## Physical collision property: true if block is solid.
var is_solid: bool = true

## Occlusion calculation property: true if block allows light rays or is partially clear.
var is_transparent: bool = false

## The number of hits required by the player to break this block type.
## Default is 1 (instant break). Harder materials override this in constructors.
var mining_resistance: int = 1

## Procedural flat fallback colors for mesh-generation without graphics card support.
var color_top: Color = Color.WHITE
var color_side: Color = Color.WHITE
var color_bottom: Color = Color.WHITE

## Geometry strategy representation determining custom winding boundaries (Slabs, Steps, Fences).
var geometry: IVoxelGeometry

# ==============================================================================
# SOLID OCP SPAWNING ATTRIBUTES (DIP / OCP Compliance)
# ==============================================================================
## True if entities can stand on top of this block as their ground surface (Grass, Sand, Snow, Dirt).
var is_spawn_surface: bool = false

## True if the Spawning Solver can penetrate/pass through this block (e.g. Air, Roofs, Leaves).
var is_spawn_penetrable: bool = false

# ==============================================================================
# OCP GATHERING PROPERTIES (SOLID OCP Compliance)
# ==============================================================================
## The Item ID dropped when this block is broken by the player.
## Defaults to -1, which automatically resolves to the block's own Type ID.
var drop_item_id: int = -1

## The quantity of items dropped when broken by the player.
var drop_quantity: int = 1

# ==============================================================================
# DECOUPLED VISUAL ATTRIBUTES (DDD Pure Data)
# Evaluated polymorphically by Infrastructure layers to assemble PBR materials automatically.
# ==============================================================================
## Base file name for the albedo map (e.g. "stone.png")
var texture_file_name: String = ""

## Base file name for the associated normal map (e.g. "stone_normal.png")
var normal_file_name: String = ""

## Surface micro-roughness value [0.0 - 1.0] for light scattering calculations.
var roughness: float = 0.85

## Surface metallic reflection value [0.0 - 1.0].
var metallic: float = 0.0

## Maps material processing groups: "default", "foliage" (wind sway), "liquid_water", "liquid_lava"
var rendering_type: String = "default"

## High-fidelity cyber glow properties.
var is_emissive: bool = false
var emission_color: Color = Color.BLACK
var emission_energy: float = 0.0


func _init() -> void:
	# Default Fallback: Standard 1x1x1 solid cube
	geometry = FullCubeGeometry.new()


## Returns the dynamically translated block name string based on the active OS locale.
func get_localized_name() -> String:
	return tr(translation_key)


## Returns the Item ID dropped by this block.
## If drop_item_id is left at -1, it defaults to the block's own type.
func get_drop_item_id() -> int:
	if drop_item_id == -1:
		return type
	return drop_item_id


## Returns the quantity of items dropped when mined.
func get_drop_quantity() -> int:
	return drop_quantity
