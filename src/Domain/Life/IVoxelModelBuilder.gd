# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Interfaces)
# Class: IVoxelModelBuilder
# Description: Pure Domain Strategy Interface defining the contract for any 
#              procedural voxel model sculptor.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the drawing 
#   contract, separating cuboid sculpting algorithms from state machines.
# - Open-Closed Principle (OCP): Enables adding infinite new visual styles or 
#   professions (like mages, miners, or astronauts) by creating concrete builders 
#   that implement this interface, completely closing the core renderer to changes.
# - Liskov Substitution Principle (LSP): Subclasses fully implement this contract 
#   to be processed polymorphically by the visual presenter.
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
	# Evitamos advertencias de parámetros no utilizados en el contrato abstracto
	var _vc := _visual_component
	var _sc := _skin_color
	var _cc := _clothing_color
	var _hc := _hair_color
	var _bid := _biome_id
	
	assert(false, "[IVoxelModelBuilder ERROR] build_model must be implemented by concrete subclasses.")
