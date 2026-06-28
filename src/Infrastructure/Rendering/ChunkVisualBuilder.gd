# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Rendering Service responsible for evaluating raw
#              domain chunks and compiling their physical and visual transformation
#              data for rendering.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by offloading 3D matrix math and MultiMesh packaging
#              away from the WorldController.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkVisualBuilder.gd
# ==============================================================================
class_name ChunkVisualBuilder
extends RefCounted

## Extracts block data from a chunk and packages it into Transform3D arrays 
## for MultiMesh rendering and StaticBody3D collision generation.
## Returns a Dictionary containing "multimesh" and "collision" keys.
static func extract_render_data(chunk: Chunk) -> Dictionary:
	var render_data: Dictionary = {}
	var collision_transforms: Array[Transform3D] = []
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				
				if block_type == BlockType.Type.AIR:
					continue
					
				# Calculate the local origin offset for the 1x1x1 cube
				var local_pos := Vector3(x, y, z)
				var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
				var t := Transform3D(Basis(), transform_pos)
				
				# Group transforms by their BlockType for chunk-partitioned rendering
				if not render_data.has(block_type):
					render_data[block_type] = []
				render_data[block_type].append(t)
				
				# Only solid blocks are compiled into physics colliders
				if BlockType.is_solid(block_type):
					collision_transforms.append(t)
					
	return {
		"multimesh": render_data,
		"collision": collision_transforms
	}
