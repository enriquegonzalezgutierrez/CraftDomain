# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain abstract class representing the strategy contract 
#              for using an active inventory item.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only defines how items are used.
#              - Open-Closed Principle (OCP): Easily extensible with new item actions 
#                without modifying the interaction handlers.
#              - Dependency Inversion Principle (DIP): Operates entirely on 
#                abstract interfaces (IInventory, VoxelEntity, IWorldModifier) 
#                instead of concrete scene-tree controllers.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/ItemUsageStrategy.gd
# ==============================================================================
class_name ItemUsageStrategy
extends RefCounted

## Abstract Contract: Returns true if the item can be used under the current parameters.
func can_use(player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	# Avoid unused parameter warnings in the abstract interface base class
	var _p_hp := player_health
	var _inv := inventory
	var _coord := target_coord
	var _norm := normal
	var _w_state := world_state
	return false


## Abstract Contract: Executes the item's custom business logic.
## DIP COMPLIANCE: Replaced Node3D concrete parameter with IWorldModifier interface.
func use(player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_modifier: IWorldModifier) -> void:
	# Avoid unused parameter warnings in the abstract interface base class
	var _p_hp := player_health
	var _inv := inventory
	var _coord := target_coord
	var _norm := normal
	var _modifier := world_modifier
	pass
