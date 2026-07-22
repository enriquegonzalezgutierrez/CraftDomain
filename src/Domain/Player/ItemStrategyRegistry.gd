# ==============================================================================
# Pathfile: res://src/Domain/Player/ItemStrategyRegistry.gd
# Description: Pure Domain Registry mapping item IDs to their respective usage
#              strategies (Block placement, food consumption, relics, tools).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ItemStrategyRegistry
extends RefCounted

const PLACEABLE_BLOCK_PATH: String = "res://src/Domain/Player/PlaceableBlockStrategy.gd"
const CONSUMABLE_ITEM_PATH: String = "res://src/Domain/Player/ConsumableItemStrategy.gd"
const PLANTABLE_ITEM_PATH: String = "res://src/Domain/Player/PlantableItemStrategy.gd"
const SLAB_PLACEMENT_PATH: String = "res://src/Domain/Player/SlabPlacementStrategy.gd"
const CHRONO_SCYTHE_PATH: String = "res://src/Domain/Player/ChronoScytheStrategy.gd"
const CHRONO_SHIFT_PATH: String = "res://src/Domain/Player/ChronoShiftStrategy.gd"
const DATA_LINKER_PATH: String = "res://src/Domain/Player/DataLinkerStrategy.gd"

static var _strategies: Dictionary = {}
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_default_strategies()


static func _register_default_strategies() -> void:
	_register_block_strategies()
	_register_consumable_and_crop_strategies()
	_register_relic_and_tool_strategies()


static func _register_block_strategies() -> void:
	var placeable_res := load(PLACEABLE_BLOCK_PATH) as GDScript
	if placeable_res == null:
		return
		
	register_strategy(1, placeable_res.new(1, BlockType.Type.STONE))
	register_strategy(2, placeable_res.new(2, BlockType.Type.DIRT))
	register_strategy(3, placeable_res.new(3, BlockType.Type.GRASS))
	register_strategy(4, placeable_res.new(4, BlockType.Type.WOOD))
	register_strategy(5, placeable_res.new(5, BlockType.Type.LEAVES))
	register_strategy(15, placeable_res.new(15, BlockType.Type.LAVA))
	register_strategy(28, placeable_res.new(28, BlockType.Type.DIAMOND_ORE))
	register_strategy(29, placeable_res.new(29, BlockType.Type.OAK_PLANKS))
	register_strategy(30, placeable_res.new(30, BlockType.Type.GLOWSTONE))


static func _register_consumable_and_crop_strategies() -> void:
	var consumable_res := load(CONSUMABLE_ITEM_PATH) as GDScript
	var plantable_res := load(PLANTABLE_ITEM_PATH) as GDScript
	var slab_res := load(SLAB_PLACEMENT_PATH) as GDScript
	
	if consumable_res != null:
		register_strategy(16, consumable_res.new(16, 1))
	if plantable_res != null:
		register_strategy(18, plantable_res.new(18, BlockType.Type.CROP_SEED))
	if slab_res != null:
		register_strategy(26, slab_res.new(26))


static func _register_relic_and_tool_strategies() -> void:
	var scythe_res := load(CHRONO_SCYTHE_PATH) as GDScript
	var shift_res := load(CHRONO_SHIFT_PATH) as GDScript
	var linker_res := load(DATA_LINKER_PATH) as GDScript
	
	if scythe_res != null:
		register_strategy(85, scythe_res.new())
	if shift_res != null:
		register_strategy(86, shift_res.new())
	if linker_res != null:
		register_strategy(87, linker_res.new())


## Public Registry API: Binds a custom usage strategy to an item ID.
static func register_strategy(item_id: int, strategy: ItemUsageStrategy) -> void:
	if strategy != null:
		_strategies[item_id] = strategy


## Public Router API: Retrieves the strategy associated with an item ID.
static func get_strategy(item_id: int) -> ItemUsageStrategy:
	_ensure_initialized()
	if _strategies.has(item_id):
		return _strategies[item_id] as ItemUsageStrategy
	return null
