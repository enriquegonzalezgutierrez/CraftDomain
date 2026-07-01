# ==============================================================================
# Project: CraftDomain
# Description: Domain Registry mapping item IDs to their respective usage strategies.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates item-to-behavior 
#                mappings.
#              - Open-Closed Principle (OCP): Dynamically extensible. New items 
#                can register their custom strategy instances at runtime.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/ItemStrategyRegistry.gd
# ==============================================================================
class_name ItemStrategyRegistry
extends RefCounted

## Dynamic registry mapping item_id (int) to its concrete ItemUsageStrategy.
static var _strategies: Dictionary = {}


## Static constructor: Executed automatically on boot by Godot.
static func _static_init() -> void:
	# 1. Structural blocks placements (Item ID -> Strategy mapping)
	register_strategy(1, PlaceableBlockStrategy.new(1, BlockType.Type.STONE))
	register_strategy(2, PlaceableBlockStrategy.new(2, BlockType.Type.DIRT))
	register_strategy(3, PlaceableBlockStrategy.new(3, BlockType.Type.GRASS))
	register_strategy(4, PlaceableBlockStrategy.new(4, BlockType.Type.WOOD))
	register_strategy(5, PlaceableBlockStrategy.new(5, BlockType.Type.LEAVES))
	
	# 2. Liquids placement (Lava Bucket)
	register_strategy(15, PlaceableBlockStrategy.new(15, BlockType.Type.LAVA))
	
	# 3. Consumable food healing (Fried Chicken)
	register_strategy(16, ConsumableItemStrategy.new(16, 1))
	
	# 4. Agricultural crop planting (Seeds)
	register_strategy(18, PlantableItemStrategy.new(18, BlockType.Type.CROP_SEED))


## Public Registry API: Binds a custom strategy to an item ID.
static func register_strategy(item_id: int, strategy: ItemUsageStrategy) -> void:
	if strategy != null:
		_strategies[item_id] = strategy


## Public Router API: Retrieves the strategy associated with an item ID (Returns null if none).
static func get_strategy(item_id: int) -> ItemUsageStrategy:
	if _strategies.has(item_id):
		return _strategies[item_id] as ItemUsageStrategy
	return null
