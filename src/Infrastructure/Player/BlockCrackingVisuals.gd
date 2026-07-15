# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/BlockCrackingVisuals.gd
# Description: Infrastructure Component managing progressive block cracking 
#              visual overlays using high-fidelity 3D Decal projections.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the texture 
#   preloading and spatial projection of progressive damage decals.
# - 120 FPS Guardrail: Decals run entirely on the GPU, completely eliminating 
#   Z-fighting and redundant main-thread visual mesh allocations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BlockCrackingVisuals
extends Node3D

# Visual template path centralized as a constant to prevent local hardcoding (Section 5.4)
const TEXTURE_TEMPLATE_PATH: String = "res://assets/textures/cracks_%d.png"

# Array storing the 4 progressive cracking texture levels (0 to 3) in RAM
var _cracking_textures: Array[Texture2D] = []

# High-Fidelity Decal node projecting cracks over target block surfaces
var _decal_overlay: Decal


func _ready() -> void:
	name = "BlockCrackingVisuals"
	_preload_cracking_textures()
	_setup_decal_overlay()


## Preloads the progressive crack textures into RAM to prevent I/O frame drops while mining
func _preload_cracking_textures() -> void:
	_cracking_textures.clear()
	for i in range(4):
		var path := TEXTURE_TEMPLATE_PATH % i
		if ResourceLoader.exists(path):
			_cracking_textures.append(load(path) as Texture2D)
		else:
			# Safety Compile-Free Fallback Placeholder
			_cracking_textures.append(PlaceholderTexture2D.new())


## Programmatically configures and attaches the 3D Decal projector
func _setup_decal_overlay() -> void:
	_decal_overlay = Decal.new()
	_decal_overlay.name = "ProgressiveCrackingDecal"
	
	# Size slightly larger than 1.0 to ensure complete, clean face coverage
	_decal_overlay.size = Vector3(1.02, 1.02, 1.02)
	
	# Configure Decal culling masks to only paint over the solid terrain layer
	_decal_overlay.cull_mask = 1 # Solid block layer
	_decal_overlay.visible = false
	
	add_child(_decal_overlay)


## Updates the position and projected texture of the damage decal based on block coordinates
func update_cracking_overlay(coord: Vector3i, ratio: float) -> void:
	if ratio <= 0.01:
		hide_cracking_overlay()
		return
		
	if is_instance_valid(_decal_overlay):
		# Center the Decal exactly over the global coordinates of the block
		_decal_overlay.global_position = Vector3(coord) + Vector3(0.5, 0.5, 0.5)
		_decal_overlay.visible = true
		
		# Map ratio [0.0 - 1.0] to one of our 4 progressive textures [0 - 3]
		var tex_idx := clampi(floori(ratio * 4.0), 0, 3)
		if _cracking_textures.size() > tex_idx:
			_decal_overlay.texture_albedo = _cracking_textures[tex_idx]


## Completely hides the visual cracking overlay projection
func hide_cracking_overlay() -> void:
	if is_instance_valid(_decal_overlay):
		_decal_overlay.visible = false
