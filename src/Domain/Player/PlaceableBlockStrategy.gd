# ==============================================================================
# Project: CraftDomain
# Description: Concrete Domain Strategy implementing the behavior of placeable blocks.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Exclusively manages the 
#                adjacent block target offset and block placement transactions.
#              - Open-Closed Principle (OCP): Parameterized to support placing any 
#                valid voxel material dynamically.
#              - Dependency Inversion Principle (DIP): Relies entirely on the 
#                IWorldModifier abstraction instead of the concrete WorldController class.
#              MATH PRECISION FIX:
#              - Replaced direct `Vector3i(normal)` casting with explicit `round()` 
#                calls. This completely prevents precision loss where normals like 
#                (0, 0.9999, 0) were truncated to (0, 0, 0), which caused blocks 
#                to be placed inside existing blocks instead of adjacent to them.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/PlaceableBlockStrategy.gd
# ==============================================================================
class_name PlaceableBlockStrategy
extends ItemUsageStrategy

var item_id: int
var block_type: BlockType.Type


func _init(p_item_id: int, p_block_type: BlockType.Type) -> void:
	item_id = p_item_id
	block_type = p_block_type


## Concrete implementation: Returns true if the adjacent coordinate is buildable (air/liquids) and we have stock.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0 when casting to int!
	var build_coord := target_coord + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	var target_block := world_state.get_block(build_coord)
	
	# Can overwrite air and non-solid liquids like water
	return target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER


## Concrete implementation: Places the block on the calculated adjacent coordinate.
## DIP COMPLIANCE: Replaced concrete scene-tree controller with the abstract domain modifier.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_modifier: IWorldModifier) -> void:
	inventory.consume_item(item_id, 1)
	
	# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0 when casting to int!
	var build_coord := target_coord + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	if is_instance_valid(world_modifier):
		world_modifier.set_block_globally(build_coord, block_type)
