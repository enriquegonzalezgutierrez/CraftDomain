# ==============================================================================
# Project: CraftDomain
# Description: Abstract base class representing a voxel entity inside the world,
#              establishing core Liskov-Substitution-compliant interaction contracts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/VoxelEntity.gd
# ==============================================================================
class_name VoxelEntity
extends CharacterBody3D

## Abstract contract: Process direct player interactions (Overridden by subclasses, e.g. Merchant)
func interact(_player: CharacterBody3D) -> void:
	pass

## Abstract contract: Process incoming physical combat damage (Overridden by subclasses, e.g. Zombie)
func take_damage(_amount: int, _knockback_force: Vector3) -> void:
	pass
