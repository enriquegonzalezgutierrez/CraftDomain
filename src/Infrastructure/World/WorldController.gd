# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator that orchestrates the World State, 
#              procedural generation, world expanding, and real-time block editing.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldController.gd
# ==============================================================================
class_name WorldController
extends Node3D

## Core World modules.
var world_state: WorldState
var generator: WorldGenerator

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode.
var _chunk_nodes: Dictionary = {}

func _ready() -> void:
	_initialize_systems()
	_generate_spawn_world()

func _initialize_systems() -> void:
	world_state = WorldState.new()
	generator = WorldGenerator.new(98765) # Seed value for the world generator

func _generate_spawn_world() -> void:
	# Generates a 7x1x7 chunk field (49 chunks) spanning 112x16x112 blocks
	const RADIUS: int = 3
	
	# Pass 1: Create block datasets (Domain State)
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var chunk_pos := Vector3i(x, 0, z)
			var chunk := Chunk.new(chunk_pos)
			
			generator.generate_chunk(chunk)
			world_state.add_chunk(chunk)
			
	# Pass 2: Build spatial and visual meshes (Infrastructure Scene Graph)
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var chunk_pos := Vector3i(x, 0, z)
			var chunk := world_state.get_chunk(chunk_pos)
			
			if chunk != null:
				_instantiate_chunk_node(chunk)

func _instantiate_chunk_node(chunk: Chunk) -> void:
	var chunk_node := ChunkNode.new(chunk)
	add_child(chunk_node)
	_chunk_nodes[chunk.position] = chunk_node
	
	# Instruct the node to construct its physical MultiMesh and collision bounds
	chunk_node.update_mesh()

## Exposes a public, real-time API to edit blocks globally from anywhere.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	# 1. Update the underlying logical domain state
	world_state.set_block(global_pos, type)
	
	# 2. Query which chunk manages this block
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	
	# 3. Instruct only that specific chunk to redraw itself instantly
	if is_instance_valid(chunk_node):
		chunk_node.update_mesh()
