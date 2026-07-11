# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / Abstract Interfaces)
# Class: IEntityVisualRepresentation
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Abstract Strategy Interface defining the contract 
#              for any entity's visual representation (Voxel or Skeletal).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the visual assembly 
#   and skeletal blending contract, separating graphics rendering from physical controllers.
# - Open-Closed Principle (OCP): Enables adding infinite new 3D assets and rigs 
#   without modifying existing Entity scripts.
# - Dependency Inversion Principle (DIP): Physical nodes depend strictly on this 
#   abstraction rather than concrete model loader classes.
# ==============================================================================
class_name IEntityVisualRepresentation
extends Resource


## Contract: Builds and instantiates the 3D visual nodes relative to the target parent
func build_representation(_host: CharacterBody3D, _target_parent: Node3D) -> void:
	assert(false, "[IEntityVisualRepresentation] build_representation() must be implemented by concrete subclass.")


## Contract: Synchronizes skeletal/procedural movement states based on velocity
func animate_movement(_velocity_flat: Vector2, _is_on_floor: bool, _delta: float) -> void:
	assert(false, "[IEntityVisualRepresentation] animate_movement() must be implemented by concrete subclass.")


## Contract: Triggers visual attack/slash/bite feedback (Skeletal or Procedural)
func trigger_attack_visuals() -> void:
	assert(false, "[IEntityVisualRepresentation] trigger_attack_visuals() must be implemented by concrete subclass.")


## Contract: Supplies the required physical bounding box dimensions
func get_collision_box_size() -> Vector3:
	assert(false, "[IEntityVisualRepresentation] get_collision_box_size() must be implemented by concrete subclass.")
	return Vector3(0.6, 0.8, 0.6)


## Contract: Supplies the required physical collision center offset
func get_collision_box_position() -> Vector3:
	assert(false, "[IEntityVisualRepresentation] get_collision_box_position() must be implemented by concrete subclass.")
	return Vector3(0.0, 0.4, 0.0)
