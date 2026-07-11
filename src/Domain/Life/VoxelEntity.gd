# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / Aggregate Roots)
# Class: VoxelEntity
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure domain model representing a voxel entity's core logic and state.
#              Strictly DDD compliant (completely agnostic of Godot's physics engine).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages state transformations 
#   for entity health, damage, and death cycles.
# ==============================================================================
class_name VoxelEntity
extends RefCounted

## Domain events used to notify the Infrastructure layer (Presentation/Physics)
signal took_damage(amount: int)
signal died

var health: int
var is_dead: bool = false


func _init(initial_health: int = 3) -> void:
	health = initial_health


## Domain logic: Processes incoming combat damage and manages entity lifecycle state.
func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	health -= amount
	took_damage.emit(amount)
	
	if health <= 0:
		is_dead = true
		died.emit()
