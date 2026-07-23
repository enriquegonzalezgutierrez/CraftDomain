# ==============================================================================
# Pathfile: res://src/Domain/Life/IVoxelModelBuilder.gd
# Description: Pure Domain Strategy Interface defining the contract for any 
#              procedural voxel model sculptor.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IVoxelModelBuilder
extends RefCounted

## Abstract Contract: Sculpts the visual block-boxes, attaches accessories (weapons, hats),
## and wires the joints dynamically.
## [param visual_component]: Sibling component holding joint Node3D references to attach meshes.
## [param skin_color]: Deterministic skin tone variety.
## [param clothing_color]: Deterministic tunic/clothing variety.
## [param hair_color]: Deterministic hair variety.
## [param biome_id]: Active biome ID, used for climate-themed robes/hats.
func build_model(
	_visual_component: Object, 
	_skin_color: Color, 
	_clothing_color: Color, 
	_hair_color: Color, 
	_biome_id: int
) -> void:
	# Avoid unused parameters warnings in this abstract base interface
	var _vc: Object = _visual_component
	var _sc: Color = _skin_color
	var _cc: Color = _clothing_color
	var _hc: Color = _hair_color
	var _bid: int = _biome_id
	
	assert(false, "[IVoxelModelBuilder ERROR] build_model must be implemented by concrete subclasses.")
