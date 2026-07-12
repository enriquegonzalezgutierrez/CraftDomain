# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/VoxelInteractionSolver.gd
# Description: Static helper class calculating coordinate vectors, player
#              collisions, and block placement validations (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelInteractionSolver
extends RefCounted


## Resolves the target coordinate and hit normal from the RayCast3D.
## Returns a Dictionary with keys "target_coord" (Vector3i), "hit_normal" (Vector3),
## "build_coord" (Vector3i) and "hit_pos_y" (float).
static func resolve_targeted_coords(raycast: RayCast3D, camera: Camera3D) -> Dictionary:
	if not is_instance_valid(raycast) or not raycast.is_colliding() or not is_instance_valid(camera):
		return {}
		
	var hit_normal := raycast.get_collision_normal()
	var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
	if hit_normal.dot(r_dir) > 0.0:
		hit_normal = -hit_normal
		
	var hit_pos := raycast.get_collision_point() + (r_dir * 0.05)
	var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
	
	# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0 when casting to int!
	var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
	
	return {
		"target_coord": target_coord,
		"hit_normal": hit_normal,
		"build_coord": build_coord,
		"hit_pos_y": hit_pos.y
	}


## Checks if a block placed at the build coordinate would collide with the player's body AABB.
static func does_block_collide_with_player(build_coord: Vector3i, player: CharacterBody3D) -> bool:
	if not is_instance_valid(player):
		return false
	var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
	var player_aabb := AABB(player.global_position - Vector3(0.35, 0.05, 0.35), Vector3(0.70, 1.85, 0.70))
	return player_aabb.intersects(block_aabb)


## Checks if a slab block clicked in the world is mergeable into a full block.
static func is_slab_mergeable(ws: WorldState, target_coord: Vector3i, hit_normal: Vector3) -> bool:
	if ws == null:
		return false
	var aimed_block := ws.get_block(target_coord)
	var is_mergeable_bottom: bool = aimed_block == BlockType.Type.STONE_SLAB_BOTTOM and int(round(hit_normal.y)) == 1
	var is_mergeable_top: bool = aimed_block == BlockType.Type.STONE_SLAB_TOP and int(round(hit_normal.y)) == -1
	return is_mergeable_bottom or is_mergeable_top


## Checks if the active item tool is a buildable block (excluding food and weapons).
static func is_active_tool_placeable(inventory_comp: InventoryComponent, active_slot: int) -> bool:
	if not is_instance_valid(inventory_comp):
		return false
	var slot_data := inventory_comp.get_slot_data(active_slot)
	if slot_data != null and slot_data.item_id != -1:
		var strategy := ItemStrategyRegistry.get_strategy(slot_data.item_id)
		return strategy != null and not (strategy is ConsumableItemStrategy)
	return false
