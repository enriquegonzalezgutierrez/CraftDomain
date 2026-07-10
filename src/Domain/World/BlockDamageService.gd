# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: BlockDamageService
# Description: Pure Domain Service managing the progressive damage, durability 
#              states, and auto-healing loops of voxel blocks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly block damage states,
#   durability lookups, and memory-safe self-healing operations.
# - Open-Closed Principle (OCP): Works polymorphically on any registered 
#   BlockDefinition without knowing concrete block types.
# - Dependency Inversion Principle (DIP): A pure data-oriented RefCounted service,
#   completely decoupled from Godot's SceneTree or physics engines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockDamageService.gd
# ==============================================================================
class_name BlockDamageService
extends RefCounted

## Inner class representing the damage record of an actively mined block coordinate
class DamageRecord:
	var remaining_hits: int
	var max_hits: int
	var idle_time: float
	
	func _init(hits: int, max_h: int) -> void:
		remaining_hits = hits
		max_hits = max_h
		idle_time = 0.0


# Active registry mapping global coordinates to their dynamic damage records: Vector3i -> DamageRecord
var _damaged_blocks: Dictionary = {}

# Time threshold (seconds) before an unattended block completely heals and clears from RAM
const HEAL_IDLE_LIMIT: float = 3.0


## Registers an impact hit at the specified global coordinate.
## Returns the remaining hits required to break the block (or 0 if it broke completely).
func register_hit(coord: Vector3i, block_type: BlockType.Type) -> int:
	# 1. If this is the first hit, query the BlockLibrary for the block's custom resistance
	if not _damaged_blocks.has(coord):
		var def := BlockLibrary.get_definition(block_type)
		var resistance := def.mining_resistance if def != null else 1
		
		# If the block has 1 resistance, it breaks instantly
		if resistance <= 1:
			return 0
			
		_damaged_blocks[coord] = DamageRecord.new(resistance, resistance)
		
	# 2. Subtract 1 impact hit from the remaining durability
	var record: DamageRecord = _damaged_blocks[coord] as DamageRecord
	record.remaining_hits -= 1
	record.idle_time = 0.0 # Reset inactivity timer on subsequent hits
	
	var remaining := record.remaining_hits
	
	# 3. If remaining hits are zero, the block has broken! Clear the record from memory
	if remaining <= 0:
		_damaged_blocks.erase(coord)
		return 0
		
	return remaining


## Returns a float value [0.0 - 1.0] representing the current damage ratio of a block.
## Used by the presentation layer to render progressive cracks.
func get_damage_ratio(coord: Vector3i) -> float:
	if not _damaged_blocks.has(coord):
		return 0.0
		
	var record: DamageRecord = _damaged_blocks[coord] as DamageRecord
	if record.max_hits <= 1:
		return 0.0
		
	# Calculate ratio (e.g. 2 remaining out of 3 max hits = 0.33 damage ratio)
	var hits_taken := float(record.max_hits - record.remaining_hits)
	return clampf(hits_taken / float(record.max_hits), 0.0, 1.0)


## Processes the self-healing loop over all damaged blocks.
## Returns an Array of coordinates that completely healed, allowing the visual 
## system to hide their respective crack overlays.
func process_healing(delta: float) -> Array[Vector3i]:
	var healed_coords: Array[Vector3i] = []
	var active_keys := _damaged_blocks.keys()
	
	for coord: Vector3i in active_keys:
		var record: DamageRecord = _damaged_blocks[coord] as DamageRecord
		record.idle_time += delta
		
		if record.idle_time >= HEAL_IDLE_LIMIT:
			# Block completely healed due to inactivity. Erase from memory
			_damaged_blocks.erase(coord)
			healed_coords.append(coord)
			
	return healed_coords


## Completely clears all damage records (Useful on world unload or teleportation)
func clear_all() -> void:
	_damaged_blocks.clear()
