# ==============================================================================
# Project: CraftDomain
# Description: Pure domain model representing a chunk containing voxel grid data.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/Chunk.gd
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

## Converts 3D coordinates to flat 1D index.
func get_index(x: int, y: int, z: int) -> int:
	return x + SIZE * (y + SIZE * z)

## Gets the block type at the local coordinates.
func get_block(x: int, y: int, z: int) -> BlockType.Type:
	if not is_within_bounds(x, y, z):
		return BlockType.Type.AIR
	return _blocks[get_index(x, y, z)] as BlockType.Type

## Sets the block type at the local coordinates.
func set_block(x: int, y: int, z: int, type: BlockType.Type) -> void:
	if is_within_bounds(x, y, z):
		_blocks[get_index(x, y, z)] = type
