# ==============================================================================
# Project: CraftDomain
# Description: Domain Service representing the architectural blueprint library,
#              procedurally constructing cabins, fortresses, harbor docks,
#              trees, streetlights, and fenced merchant stalls.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureLibrary.gd
# ==============================================================================
class_name StructureLibrary
extends RefCounted

## Procedurally constructs a rustic village cabin inside a chunk.
static func build_village_cabin(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var width: int = 5
	var depth: int = 5
	var height: int = 4
	
	# 1. Foundation (Stone flooring layers)
	for x in range(width):
		var lx := start_x + x
		for z in range(depth):
			var lz := start_z + z
			for fill_y in range(ground_y - 2, ground_y + 1):
				chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)

	# 2. Hollow Wood Walls with window openings
	for y in range(1, height):
		var ly := ground_y + y
		for x in range(width):
			var lx := start_x + x
			for z in range(depth):
				var lz := start_z + z
				
				var is_edge: bool = (x == 0 or x == width - 1 or z == 0 or z == depth - 1)
				if is_edge:
					# Create doorway at front center (x=2, z=0)
					var is_door: bool = (x == 2 and z == 0 and (y == 1 or y == 2))
					# Create windows on the side walls
					var is_window: bool = ((x == 0 or x == width - 1) and z == 2 and y == 2)
					
					if is_door or is_window:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.WOOD)
				else:
					chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

	# 3. Overhanging Shrubbery Roof (Leaves)
	var roof_y := ground_y + height
	for x in range(-1, width + 1):
		var lx := start_x + x
		for z in range(-1, depth + 1):
			var lz := start_z + z
			if chunk.is_within_bounds(lx, roof_y, lz):
				chunk.set_block(lx, roof_y, lz, BlockType.Type.LEAVES)

## Procedurally constructs an open wooden market stall with fences for the merchant.
static func build_merchant_stall_with_fences(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var width: int = 4
	var depth: int = 4
	
	# 1. Floor (Stone base)
	for x in range(width):
		var lx := start_x + x
		for z in range(depth):
			var lz := start_z + z
			chunk.set_block(lx, ground_y, lz, BlockType.Type.STONE)
			
	# 2. Support Pillars (Wood corners, height 3)
	for y in range(1, 4):
		var ly := ground_y + y
		chunk.set_block(start_x, ly, start_z, BlockType.Type.WOOD)
		chunk.set_block(start_x + width - 1, ly, start_z, BlockType.Type.WOOD)
		chunk.set_block(start_x, ly, start_z + depth - 1, BlockType.Type.WOOD)
		chunk.set_block(start_x + width - 1, ly, start_z + depth - 1, BlockType.Type.WOOD)
		
	# 3. Front Counter Fence (Half-height wooden barrier on z=0, y=1)
	chunk.set_block(start_x + 1, ground_y + 1, start_z, BlockType.Type.WOOD)
	chunk.set_block(start_x + 2, ground_y + 1, start_z, BlockType.Type.WOOD)
	
	# 4. Colorful Roof (Striped Leaves/Wood canopy)
	var roof_y := ground_y + 3
	for x in range(width):
		var lx := start_x + x
		for z in range(depth):
			var lz := start_z + z
			var is_stripe: bool = (x % 2 == 0)
			if is_stripe:
				chunk.set_block(lx, roof_y, lz, BlockType.Type.LEAVES)
			else:
				chunk.set_block(lx, roof_y, lz, BlockType.Type.WOOD)

## Procedurally constructs a medieval stone watchtower on mountain peaks.
static func build_medieval_watchtower(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var size: int = 3
	var tower_height: int = 8
	
	# 1. Solid Stone Foundations
	for x in range(size):
		var lx := start_x + x
		for z in range(size):
			var lz := start_z + z
			for fill_y in range(ground_y - 3, ground_y + 1):
				chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)
				
	# 2. Hollow Stone Walls rising high into the sky
	for y in range(1, tower_height):
		var ly := ground_y + y
		for x in range(size):
			var lx := start_x + x
			for z in range(size):
				var lz := start_z + z
				var is_edge: bool = (x == 0 or x == size - 1 or z == 0 or z == size - 1)
				
				if is_edge:
					var is_window: bool = (y == 4 or y == 6) and (x == 1 or z == 1)
					if is_window:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.STONE)
				else:
					chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					
	# 3. Battlements (Parapets) at the top deck
	var roof_y := ground_y + tower_height
	for x in range(size):
		var lx := start_x + x
		for z in range(size):
			var lz := start_z + z
			chunk.set_block(lx, roof_y, lz, BlockType.Type.STONE)
			
			var is_corner: bool = (x == 0 or x == size - 1) and (z == 0 or z == size - 1)
			if is_corner:
				if chunk.is_within_bounds(lx, roof_y + 1, lz):
					chunk.set_block(lx, roof_y + 1, lz, BlockType.Type.STONE)

## Generates a small wooden pier and docking spot for boats.
static func build_harbor_pier(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var pier_length: int = 5
	
	for z in range(pier_length):
		var lz := start_z + z
		
		# Stone support posts driven down into the dirt
		for y in range(ground_y - 2, ground_y + 1):
			chunk.set_block(start_x, y, lz, BlockType.Type.STONE)
			chunk.set_block(start_x + 1, y, lz, BlockType.Type.STONE)
		
		# Wooden plank walkway surface
		chunk.set_block(start_x, ground_y + 1, lz, BlockType.Type.WOOD)
		chunk.set_block(start_x + 1, ground_y + 1, lz, BlockType.Type.WOOD)

## Procedurally constructs a natural tree trunks with a leafy canopy.
static func build_procedural_tree(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var trunk_height: int = 4
	
	# 1. Grow Wood Trunk vertically
	for y in range(1, trunk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.WOOD)
		
	# 2. Place Leaf Canopy (3x3x3 Leaves cube centered on the top trunk)
	var top_y := ground_y + trunk_height
	for x in range(-1, 2):
		for y in range(0, 3):
			for z in range(-1, 2):
				var lx := start_x + x
				var ly := top_y + y
				var lz := start_z + z
				
				# Skip the trunk core to save block calculations
				if x == 0 and z == 0 and y == 0:
					continue
					
				chunk.set_block(lx, ly, lz, BlockType.Type.LEAVES)

## Procedurally constructs a tall street lamppost.
static func build_village_streetlight(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var post_height: int = 3
	
	# 1. Tall Wooden post
	for y in range(1, post_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.WOOD)
		
	# 2. Glow stone lantern block at the top (Represented by a unique colored Stone block)
	# (We can color code it later, but using Stone is standard and fully visible)
	chunk.set_block(start_x, ground_y + post_height + 1, start_z, BlockType.Type.STONE)
