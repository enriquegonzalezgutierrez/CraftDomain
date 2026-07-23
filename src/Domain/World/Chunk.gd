# ==============================================================================
# Pathfile: res://src/Domain/World/Chunk.gd
# Description: Pure domain model representing a 16x16x16 chunk containing 
#              voxel grid data and flat packed byte array storage.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name Chunk
extends RefCounted

## Chunk dimensions (16x16x16).
const SIZE: int = 16
const TOTAL_BLOCKS: int = SIZE * SIZE * SIZE

## Flat array storing block type IDs.
var _blocks: PackedByteArray = PackedByteArray()

## Global chunk coordinate in world space (e.g., Vector3i(0, 0, 0), Vector3i(1, 0, 0)).
var position: Vector3i


func _init(p_position: Vector3i) -> void:
	position = p_position
	_blocks.resize(TOTAL_BLOCKS)
	_blocks.fill(BlockType.Type.AIR)


## Checks if coordinates are within local chunk boundaries.
func is_within_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE and z >= 0 and z < SIZE


## Gets the block type at the local coordinates.
func get_block(x: int, y: int, z: int) -> BlockType.Type:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return BlockType.Type.AIR
	return _blocks[x + SIZE * (y + SIZE * z)] as BlockType.Type


## Sets the block type at the local coordinates.
func set_block(x: int, y: int, z: int, type: BlockType.Type) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE and z >= 0 and z < SIZE:
		_blocks[x + SIZE * (y + SIZE * z)] = type
