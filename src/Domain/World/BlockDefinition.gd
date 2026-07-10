# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Value Objects)
# Class: BlockDefinition
# Description: Pure Domain Base Class describing the physical attributes, 
#              geographical properties, and decoupled visual characteristics 
#              of a voxel block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively encapsulates block metadata.
# - Open-Closed Principle (OCP): Designed as an abstract template. Subclasses 
#   override this class to define customized block properties in separate files, 
#   ensuring no parent code is ever modified to append new voxel materials.
# - Liskov Substitution Principle (LSP): Subclasses inherit this contract, 
#   ensuring they can be polymorphically processed by meshing and loading engines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockDefinition.gd
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

## Physical collision property: true if block is solid
var is_solid: bool = true

## Occlusion calculation property: true if block allows light rays or is partially clear
var is_transparent: bool = false

## The number of hits required by the player to break this block type.
## Default is 1 (instant break). Harder materials should override this in constructors.
var mining_resistance: int = 1

## Procedural flat fallback colors for mesh-generation without graphics card support
var color_top: Color = Color.WHITE
var color_side: Color = Color.WHITE
var color_bottom: Color = Color.WHITE

## Geometry strategy representation determining custom winding boundaries (Slabs, Steps, Fences)
var geometry: IVoxelGeometry

# ==============================================================================
# DECOUPLED VISUAL ATTRIBUTES (DDD Pure Data)
# Evaluated polymorphically by Infrastructure layers to assemble PBR materials automatically.
# ==============================================================================
## Base file name for the albedo map (e.g. "stone.png")
var texture_file_name: String = ""

## Base file name for the associated normal map (e.g. "stone_normal.png")
var normal_file_name: String = ""

## Surface micro-roughness value [0.0 - 1.0] for light scattering calculations
var roughness: float = 0.85

## Surface metallic reflection value [0.0 - 1.0]
var metallic: float = 0.0

## Maps material processing groups: "default", "foliage" (wind sway), "liquid_water", "liquid_lava"
var rendering_type: String = "default"

## High-fidelity cyber glow properties
var is_emissive: bool = false
var emission_color: Color = Color.BLACK
var emission_energy: float = 0.0


func _init() -> void:
	# Default Fallback: Standard 1x1x1 solid cube
	geometry = FullCubeGeometry.new()


## Returns the dynamically translated block name string based on the active OS locale
func get_localized_name() -> String:
	return tr(translation_key)
